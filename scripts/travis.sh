#! /bin/bash

if [[ "$STAGE" == 'test' ]]; then
  bundle exec rspec
elif [[ "$STAGE" == 'typecheck' ]]; then
  srb tc
elif [[ "$STAGE" == "integration" ]]; then
  unset BUNDLE_GEMFILE
  set -e

  source ./scripts/integration.sh
  setup_cluster
  setup_node

  echo travis_fold:start:generate_app
  gem install rails -v 6.0.3.4
  cd ..
  rails _6.0.3.4_ new kubyapp -d mysql
  cp -R ./kuby-core/ ./kubyapp/vendor/kuby-core
  cd kubyapp
  printf "\ngem 'kuby-core', path: 'vendor/kuby-core'\n" >> Gemfile
  bundle exec rails g kuby
  printf "Kuby.environment.docker.insert(:vendor, before: :bundler_phase) { |dockerfile| dockerfile.copy('vendor', 'vendor') }\n" >> kuby.rb
  printf "Kuby.environment.docker.image_url('kubyapp')\n" >> kuby.rb
  printf "Kuby.environment.kubernetes.plugin(:rails_app).tls_enabled(false)\n" >> kuby.rb
  echo travis_fold:end:generate_app

  echo travis_fold:start:build
  GLI_DEBUG=true bundle exec kuby -e production build
  echo travis_fold:end:build

  echo travis_fold:start:deploy
  GLI_DEBUG=true bundle exec kuby -e production deploy
  echo travis_fold:end:deploy

  curl kubyapp-web:8080
fi
