FROM debian:latest
RUN apt-get update && \
  apt-get -y install curl && \
  curl -L https://github.com/egabosh/linux-setups/raw/refs/heads/main/debian/docker/build-debian-env.sh >build-debian-env.sh && \
  bash -ex build-debian-env.sh #&& \
#  git clone https://github.com/ccxt/ccxt.git --depth 1
WORKDIR /python-dabo
RUN python3 -m venv /python-dabo
ENV PATH="/python-dabo/bin:$PATH"
RUN pip install --upgrade pip && \
  pip install ccxt tensorflow[and-cuda] pandas scikit-learn
RUN addgroup --system --gid 10000 dabo
RUN adduser --system --disabled-password --disabled-login --gid 10000 --uid 10000 --home /dabo/home dabo
ENV LANG en_US.utf8
WORKDIR /dabo/htdocs/botdata
ENTRYPOINT ["/dabo/dabo-bot.sh"]
