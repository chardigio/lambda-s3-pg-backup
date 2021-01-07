# ANYTHING BELOW THAT IS *NOT* COPY-PASTED FROM THE "Building a Custom Image for Python" SECTION OF
# https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/
# WILL BE IN BETWEEN `# *** BEGIN ***` & `# *** END ***` COMMENTS.

# Define global args
ARG FUNCTION_DIR="/home/app/"
ARG RUNTIME_VERSION="3.9"
ARG DISTRO_VERSION="3.12"

# Stage 1 - bundle base image + runtime
# Grab a fresh copy of the image and install GCC
FROM python:${RUNTIME_VERSION}-alpine${DISTRO_VERSION} AS python-alpine
# Install GCC (Alpine uses musl but we compile and link dependencies with GCC)
RUN apk add --no-cache \
    libstdc++

# Stage 2 - build function and dependencies
FROM python-alpine AS build-image
# Install aws-lambda-cpp build dependencies
RUN apk add --no-cache \
    build-base \
    libtool \
    autoconf \
    automake \
    libexecinfo-dev \
    make \
    cmake \
    libcurl
# Include global args in this stage of the build
ARG FUNCTION_DIR
ARG RUNTIME_VERSION
# Create function directory
RUN mkdir -p ${FUNCTION_DIR}
# Copy handler function

# *** BEGIN ***
# Instead of copying over the contents of an app/ directory we're just gonna copy that one file into ${FUNCTION_DIR}
COPY app.py ${FUNCTION_DIR}
# *** END ***

# Optional – Install the function's dependencies
# RUN python${RUNTIME_VERSION} -m pip install -r requirements.txt --target ${FUNCTION_DIR}
# Install Lambda Runtime Interface Client for Python
RUN python${RUNTIME_VERSION} -m pip install awslambdaric --target ${FUNCTION_DIR}

# Stage 3 - final runtime image
# Grab a fresh copy of the Python image
FROM python-alpine
# Include global arg in this stage of the build
ARG FUNCTION_DIR
# Set working directory to function root directory
WORKDIR ${FUNCTION_DIR}
# Copy in the built dependencies
COPY --from=build-image ${FUNCTION_DIR} ${FUNCTION_DIR}
# (Optional) Add Lambda Runtime Interface Emulator and use a script in the ENTRYPOINT for simpler local runs
ADD https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie /usr/bin/aws-lambda-rie
RUN chmod 755 /usr/bin/aws-lambda-rie

# *** BEGIN ***
# Here we add the important parts of https://github.com/schickling/dockerfiles/blob/master/postgres-backup-s3/Dockerfile

# Env Vars
ENV POSTGRES_DATABASE **None**
ENV POSTGRES_HOST **None**
ENV POSTGRES_PORT 5432
ENV POSTGRES_USER **None**
ENV POSTGRES_PASSWORD **None**
ENV POSTGRES_EXTRA_OPTS ''
ENV S3_ACCESS_KEY_ID **None**
ENV S3_SECRET_ACCESS_KEY **None**
ENV S3_BUCKET **None**
ENV S3_REGION us-east-1
ENV S3_PATH 'auto-backups'
ENV S3_ENDPOINT **None**
ENV S3_S3V4 no
ENV SCHEDULE **None**

# Some installations taken from install.sh which gets run in the aforementioned Dockerfile, and can be found here:
# https://github.com/schickling/dockerfiles/blob/master/postgres-backup-s3/install.sh
# Install pg_dump
RUN apk add postgresql
# Install s3 tools
RUN python${RUNTIME_VERSION} -m pip install awscli

# Make sure we can properly run these files within our docker image
COPY entry.sh ${FUNCTION_DIR}
RUN chmod 755  ${FUNCTION_DIR}/entry.sh

COPY backup.sh ${FUNCTION_DIR}
RUN chmod 755  ${FUNCTION_DIR}/backup.sh
# *** END ***

# *** BEGIN ***
# Let's run the app now in our specified location
# TODO: Is there a way to do string interpolation here so we can use ${FUNCTION_DIR}?
ENTRYPOINT [ "/home/app/entry.sh" ]
CMD [ "app.handler" ]
# *** END ***
