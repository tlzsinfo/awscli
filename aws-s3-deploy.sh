#!/bin/sh
set -e

# check environmental variables, use variable D to prevent execution by variable expansion
D=${AWS_DEFAULT_REGION?Environmental variable is not set}
D=${CODE_DEPLOY_APPLICATION_NAME?Environmental variable is not set}
D=${CODE_DEPLOY_S3_BUCKET_NAME?Environmental variable is not set}
D=${APP_DIR?Environmental variable is not set}

# set deploy group to CIRCLE_BRANCH if not specified
if [[ -z "${CODE_DEPLOY_GROUP_NAME}" ]]; then
  DEPLOY_GROUP=${CIRCLE_BRANCH?Environmental variable is not set}
else
  DEPLOY_GROUP=${CODE_DEPLOY_GROUP_NAME}
fi

# set behavior if file exists case to DISALLOW(default) if not specified
if [[ -z "${CODE_DEPLOY_FILE_EXISTS_BEHAVIOR}" ]]; then
  FILE_EXISTS_BEHAVIOR=DISALLOW
else
  FILE_EXISTS_BEHAVIOR=${CODE_DEPLOY_FILE_EXISTS_BEHAVIOR}
fi

# ZIPNAME=${CIRCLE_BRANCH}"-"${CIRCLE_BUILD_NUM}"-"${CIRCLE_SHA1}".zip"

if [[ "${CODE_DEPLOY_GROUP_NAME}" = "prod-39marche-deploy-group" ]]; then
  ZIPNAME="deployment/docomo-fresh-first-tags-"${CIRCLE_BUILD_NUM}".zip"
elif [[ "${CODE_DEPLOY_GROUP_NAME}" = "dev-39marche-deploy-group" ]]; then
  ZIPNAME="deployment/docomo-39marche-"${CIRCLE_BRANCH}"-"${CIRCLE_BUILD_NUM}".zip"
else
  ZIPNAME=${CIRCLE_BRANCH}"-"${CIRCLE_BUILD_NUM}"-"${CIRCLE_SHA1}".zip"
fi

echo "The zip file name is ZIPNAME. -> ${ZIPNAME}";

# push apps to S3
S3INFO=`aws deploy push \
          --application-name ${CODE_DEPLOY_APPLICATION_NAME} \
          --s3-location s3://${CODE_DEPLOY_S3_BUCKET_NAME}/${ZIPNAME} \
          --source ${APP_DIR} | grep eTag`
ETAG=`echo "${S3INFO}" | sed -e 's/^.*eTag=\([^ ]*\) .*$/\1/g'`

echo "Push apps to S3 is done. ETAG -> ${ETAG}";

# create codedeploy deployment
DEPLOY=`aws deploy create-deployment \
   --application-name ${CODE_DEPLOY_APPLICATION_NAME} \
   --s3-location bucket=${CODE_DEPLOY_S3_BUCKET_NAME},key=${ZIPNAME},bundleType=zip,eTag=${ETAG} \
   --deployment-group-name ${DEPLOY_GROUP} \
   --file-exists-behavior ${FILE_EXISTS_BEHAVIOR}`


DEPLOYMENT_ID=`echo ${DEPLOY} | jq .deploymentId | sed -e 's/"//g'`

echo "create codedeploy deployment is done. DEPLOYMENT_ID -> ${DEPLOYMENT_ID}"

# wait for codedeploy finishes deployment
aws deploy wait deployment-successful --deployment-id ${DEPLOYMENT_ID}
