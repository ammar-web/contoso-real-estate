#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source .env
cd ../..

# Allow silent installation of Azure CLI extensions
az config set extension.use_dynamic_install=yes_without_prompt

# Deploy portal --------------------------------------------------------------
echo "Deploying portal..."
pushd packages/website
npx -y @azure/static-web-apps-cli@1.0.6 deploy \
  --app-name "$SWA_PORTAL_NAME" \
  --deployment-token "$SWA_PORTAL_DEPLOYMENT_TOKEN" \
  --env "production" \
  --verbose
popd
echo "Portal deployed to $SWA_PORTAL_URL"

# Deploy api function --------------------------------------------------------
# TODO
# echo "Deploying api..."
# pushd packages/api
# npx -y azure-functions-core-tools@4 azure functionapp publish "$FUNCTION_APP_NAME" \
#   --verbose
# popd

# Deploy cms container app ---------------------------------------------------
echo "Deploying cms..."
container_app_cms_host=$(
  az containerapp up \
    --name "$CONTAINER_APP_CMS_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --environment "$CONTAINER_APP_ENV_NAME" \
    --registry-server "$REGISTRY_SERVER" \
    --registry-username "$REGISTRY_USERNAME" \
    --registry-password "$REGISTRY_PASSWORD" \
    --image "$REGISTRY_SERVER/cms:v1" \
    --target-port 1337 \
    --ingress external \
    --secrets   "databaseusername=$STRAPI_DATABASE_USERNAME" \
                "databasepassword=$STRAPI_DATABASE_PASSWORD" \
    --env-var   "DATABASE_HOST=$STRAPI_DATABASE_HOST" \
                "DATABASE_PORT=$STRAPI_DATABASE_PORT" \
                "DATABASE_NAME=$STRAPI_DATABASE_NAME" \
                "DATABASE_SSL=$STRAPI_DATABASE_SSL" \
                "DATABASE_USERNAME=secretref:databaseusername" \
                "DATABASE_PASSWORD=secretref:databasepassword" \
    --scale-rule-name http-rule \
    --scale-rule-type http \
    --scale-rule-http-concurrency 1000 \
    --min-replicas 1 \
    --query "properties.configuration.ingress.fqdn" \
    --output tsv
)
container_app_cms_url="https://$container_app_cms_host"
echo "CMS deployed to $container_app_cms_url"

# Deploy blog container app --------------------------------------------------
echo "Deploying blog..."
container_app_blog_host=$(
  az containerapp up \
    --name "$CONTAINER_APP_BLOG_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --environment "$CONTAINER_APP_ENV_NAME" \
    --registry-server "$REGISTRY_SERVER" \
    --registry-username "$REGISTRY_USERNAME" \
    --registry-password "$REGISTRY_PASSWORD" \
    --image "$REGISTRY_SERVER/blog:v1" \
    --target-port 3000 \
    --ingress external \
    --env-vars "NEXT_PUBLIC_STRAPI_API_URL=$container_app_cms_url" \
    --scale-rule-name http-rule \
    --scale-rule-type http \
    --scale-rule-http-concurrency 1000 \
    --min-replicas 1 \
    --query "properties.configuration.ingress.fqdn" \
    --output tsv
)
container_app_blog_url="https://$container_app_blog_host"
echo "Blog deployed to $container_app_blog_url"

# Deploy stripe container app ------------------------------------------------
# TODO
