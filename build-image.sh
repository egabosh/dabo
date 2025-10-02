#!/bin/bash
cd /home/docker/dabo.$(hostname)

if git log --since="24 hours ago" | grep -q commit
then
  git push origin main
else
  echo "No change in the last 24 hours. Stopping!"
  exit 1
fi

if [ $(find version -mmin -1440) ]
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
changes=$(git log --since="24 hours ago")

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
  time docker buildx build \
   -f Dockerfile \
   --platform linux/amd64,linux/arm64 \
   -t ghcr.io/egabosh/${edition}:0.${version} \
   -t ghcr.io/egabosh/${edition}:latest \
   --build-arg VERSION=0.$version \
   --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
   --build-arg PIP_PACKAGES="$pip_packages" \
   --push .
  set +x
done

echo $version >version
git commit -m "new image version" version
git push origin main
echo "====== ghcr.io/egabosh/${edition}:0.${version} released!!!"

