FROM node:24-bookworm-slim AS node

FROM ruby:3.3-slim AS base

ARG APP_HOME=/app
ARG APP_UID=1000
ARG APP_GID=1000

ENV LANG=C.UTF-8 \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_BIN=/usr/local/bundle/bin \
    GEM_HOME=/usr/local/bundle \
    HOME=/app \
    PATH=/usr/local/bundle/bin:/usr/local/bin:/usr/bin:/bin \
    RAILS_ENV=development

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      bash \
      ca-certificates \
      curl \
      libpq5 \
      libvips \
      libyaml-0-2 \
      postgresql-client \
      shared-mime-info \
      tzdata && \
    rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/ /usr/local/

RUN gem install bundler --no-document

RUN mkdir -p "${APP_HOME}" "${BUNDLE_PATH}" && \
    chown -R "${APP_UID}:${APP_GID}" "${APP_HOME}" "${BUNDLE_PATH}"

WORKDIR ${APP_HOME}

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libpq-dev \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./

# Keep gems in their own layer so app-only edits rebuild quickly.
RUN bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache && \
    chown -R "${APP_UID}:${APP_GID}" "${BUNDLE_PATH}"

FROM base AS development

COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --from=build --chown=${APP_UID}:${APP_GID} ${BUNDLE_PATH} ${BUNDLE_PATH}
COPY --chown=${APP_UID}:${APP_GID} . ${APP_HOME}

RUN mkdir -p tmp/pids log && chown -R "${APP_UID}:${APP_GID}" "${APP_HOME}"

USER ${APP_UID}:${APP_GID}

EXPOSE 3000

ENTRYPOINT ["docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
