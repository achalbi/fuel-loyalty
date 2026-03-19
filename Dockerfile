# ---------- Builder Stage ----------
FROM ruby:3.3-slim AS builder

# System dependencies for native gems
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    libyaml-dev \
    pkg-config \
    git \
    curl \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---- Bundler: enforce production determinism ----
ENV RAILS_ENV=production \
    RACK_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test"

# Hard enforcement (prevents your debug gem issue)
RUN bundle config set deployment 'true' && \
    bundle config set without 'development test'

# Copy only gem files first (cache optimization)
COPY Gemfile Gemfile.lock ./

# Clean install (avoid layer contamination)
RUN rm -rf /usr/local/bundle && \
    bundle install --jobs=4 --retry=3

# Copy app after gems
COPY . .

# Safety check (fail fast if dev gems leaked)
RUN bundle list | grep debug && exit 1 || echo "OK: no debug gem"

# Precompile assets
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile


# ---------- Runtime Stage ----------
FROM ruby:3.3-slim AS runtime

# Minimal runtime dependencies
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    libyaml-0-2 \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy only what is required
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

# ---- Runtime ENV ----
ENV RAILS_ENV=production \
    RACK_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test" \
    PORT=8080

EXPOSE 8080

# Optional but recommended (Cloud Run readiness)
ENV RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

# Boot server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]