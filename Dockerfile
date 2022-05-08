ARG product_version=7.0.1
ARG build_number=37
ARG oo_root='/var/www/onlyoffice/documentserver'

## Setup
FROM onlyoffice/documentserver:${product_version}.${build_number} as setup-stage
ARG product_version
ARG build_number
ARG oo_root

ENV PRODUCT_VERSION=${product_version}
ENV BUILD_NUMBER=${build_number}

ARG build_deps="git make g++ nodejs npm"
RUN apt-get update && apt-get install -y ${build_deps}
RUN npm install -g pkg grunt

WORKDIR /build



## Clone
FROM setup-stage as clone-stage
ARG tag=v${PRODUCT_VERSION}.${BUILD_NUMBER}

RUN git clone --quiet --branch $tag --depth 1 https://github.com/ONLYOFFICE/build_tools.git /build/build_tools
RUN git clone --quiet --branch $tag --depth 1 https://github.com/ONLYOFFICE/server.git      /build/server

COPY server.patch /build/server.patch
RUN cd /build/server   && git apply /build/server.patch



## Build
FROM clone-stage as build-stage

# build server with license checks patched
WORKDIR /build/server
RUN make
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/FileConverter --targets=node10-linux -o /build/converter
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/DocService --targets=node10-linux --options max_old_space_size=4096 -o /build/docservice


## Final image
FROM onlyoffice/documentserver:${product_version}.${build_number}
ARG oo_root

# Enable mobile edit feature
RUN sed -i 's/isSupportEditFeature=function(){return!1}/isSupportEditFeature=function(){return 1}/g' /var/www/onlyoffice/documentserver/web-apps/apps/spreadsheeteditor/mobile/dist/js/app.js
RUN sed -i 's/isSupportEditFeature=function(){return!1}/isSupportEditFeature=function(){return 1}/g' /var/www/onlyoffice/documentserver/web-apps/apps/documenteditor/mobile/dist/js/app.js
RUN sed -i 's/isSupportEditFeature=function(){return!1}/isSupportEditFeature=function(){return 1}/g' /var/www/onlyoffice/documentserver/web-apps/apps/presentationeditor/mobile/dist/js/app.js

#server
COPY --from=build-stage /build/converter  ${oo_root}/server/FileConverter/converter
COPY --from=build-stage /build/docservice ${oo_root}/server/DocService/docservice
