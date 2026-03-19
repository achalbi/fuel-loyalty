FROM ruby:3.3-slim

WORKDIR /app

RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

ENV RAILS_ENV=production
ENV PORT=8080

# Required for Rails static assets on Cloud Run
ENV RAILS_SERVE_STATIC_FILES=true

# Precompile assets (Sprockets)
RUN bundle exec rails assets:precompile

EXPOSE 8080

CMD ["bash", "-c", "bundle exec puma -C config/puma.rb"]