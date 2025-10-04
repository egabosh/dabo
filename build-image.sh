#!/bin/bash
cd /home/docker/dabo.$(hostname)

if git log --since="24 hours ago" | grep -q commit
then
  git push origin main
else
  echo "No change in the last 24 hours. Stopping!"
  exit 1
fi

if [ $(find version -mmin -1430) ]
then
  echo "Last version younger then 24 hours"
  exit 2
fi

if cat ~/.docker/config.json | jq '.auths["ghcr.io"]' -e > /dev/null 
then 
  echo "Logged in" >/dev/null
else
  echo "Please first log in with:
echo APIKEY | docker login ghcr.io -u egabosh --password-stdin"
  exit 1
fi

version=$(cat version)
version=$((version+1))

ocker loout
set -e
docker login ghcr.io

for edition in dabo dabo-without-ai 
do
  date
  echo "====== Building ghcr.io/egabosh/${edition}:0.${version}"
  set -x
  docker buildx ls | grep -q $edition || docker buildx create --name $edition
  docker buildx use --builder $edition --default
  pip_packages="ccxt tensorflow[and-cuda] pandas scikit-learn"
  [[ "$edition" == "dabo-without-ai" ]] && pip_packages="ccxt"
  builddate=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  description="dabo crypto trading bot ($edition)"
  time docker buildx build \
   -f Dockerfile \
   --platform linux/amd64,linux/arm64 \
   -t ghcr.io/egabosh/${edition}:0.${version} \
   -t ghcr.io/egabosh/${edition}:latest \
   --build-arg VERSION=0.$version \
   --build-arg BUILD_DATE=$builddate \
   --build-arg PIP_PACKAGES="$pip_packages" \
   --build-arg DESCRIPTION="$description" \
   --annotation "index,manifest:org.opencontainers.image.source=https://github.com/egabosh/dabo" \
   --annotation "index,manifest:org.opencontainers.image.description=$description" \
   --annotation "index,manifest:org.opencontainers.image.version=0.$version" \
   --annotation "index,manifest:org.opencontainers.image.authors=Oliver Bohlen (aka olli/egabosh)" \
   --annotation "index,manifest:org.opencontainers.image.licenses=GPL-3.0 (for dabo-bot in /dabo)" \
   --annotation "index,manifest:org.opencontainers.image.created=$builddate" \
   --annotation "index,manifest:org.opencontainers.image.vendor=egabosh" \
   --annotation "index,manifest:org.opencontainers.image.documentation=https://github.com/egabosh/dabo#readme" \
   --annotation "index,manifest:org.opencontainers.image.base.name=Debian Linux" \
   --annotation "index,manifest:org.opencontainers.image.base.licenses=Various, see https://www.debian.org/legal/licenses/" \
   --push .
  set +x
done

echo $version >version
git commit -m "new image version" version
git push origin main
echo "====== ghcr.io/egabosh/${edition}:0.${version} released!!!"

