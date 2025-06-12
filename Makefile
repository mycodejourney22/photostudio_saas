# Makefile (for easy test running)
.PHONY: test test-core test-smoke test-models test-system setup-test

# Run all tests
test:
	bundle exec rspec

# Run core feature tests
test-core:
	bundle exec rake test:core

# Run smoke tests
test-smoke:
	bundle exec rake test:smoke

# Run model tests only
test-models:
	bundle exec rspec spec/models/

# Run system tests
test-system:
	bundle exec rspec spec/system/

# Setup test database
setup-test:
	RAILS_ENV=test bundle exec rails db:drop db:create db:migrate

# Run tests with coverage
test-coverage:
	COVERAGE=true bundle exec rspec

# Run performance tests
test-performance:
	bundle exec rspec spec/performance/

# Clean test artifacts
clean-test:
	rm -rf coverage/
	rm -f spec/examples.txt
	rm -rf tmp/screenshots/
