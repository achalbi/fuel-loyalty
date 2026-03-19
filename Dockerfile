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

# Bundler config (deterministic + production)
ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development test"

COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install

# Copy app
COPY . .

# Precompile assets (no Node assumed)
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile


# ---------- Runtime Stage ----------
FROM ruby:3.3-slim AS runtime

# Only runtime dependencies (minimal footprint)
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    libyaml-0-2 \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy app from builder
COPY --from=builder /app /app

# Cloud Run expects this
ENV RAILS_ENV=production \
    RACK_ENV=production \
    PORT=8080

EXPOSE 8080

# Use Puma (default Rails production server)
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]