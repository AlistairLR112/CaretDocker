FROM rocker/r-base
MAINTAINER Alistair Rogers

WORKDIR /app/
#Hello

# Required in order to get Jug to work in Debian

RUN apt-get update && apt-get install libcurl4-openssl-dev

COPY app.R requirements.R /app/
COPY model.RDS preprocessing.RDS /app/

RUN Rscript /app/requirements.R

EXPOSE 8080

ENTRYPOINT Rscript ./app.R

