#
# Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Define helidon image version for all stages
FROM helidon/jdk8-graalvm-maven:1.0.0-rc13 as build-img

# Cache maven dependencies. Only reload maven dependencies when pom changes.
FROM build-img as mavencache
ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn
COPY pom.xml /mvn/
WORKDIR /mvn
RUN mvn package dependency:resolve dependency:resolve-plugins

# 1st stage, build the app
FROM build-img as build
ENV MAVEN_OPTS=-Dmaven.repo.local=/mvn
COPY --from=mavencache /mvn/ /mvn/

WORKDIR /helidon

# Create a first layer to cache the "Maven World" in the local repository.
# Incremental docker builds will always resume after that, unless you update
# the pom
ADD pom.xml .
RUN mvn package -Pnative-image -Dnative.image.skip -DskipTests

# Do the Maven build!
# Incremental docker builds will resume here when you change sources
ADD src src
RUN mvn package -Pnative-image -Dnative.image.buildStatic -DskipTests

RUN echo "done!"

# 2nd stage, build the runtime image
FROM scratch
WORKDIR /helidon

# Copy the binary built in the 1st stage
COPY --from=build /helidon/target/helidon-quickstart .

ENTRYPOINT ["./helidon-quickstart"]

EXPOSE 8080
