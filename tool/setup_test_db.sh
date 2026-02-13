#!/bin/bash
# Setup script for SpacetimeDB test environment
# This script sets up a local SpacetimeDB instance and publishes the test module

set -e  # Exit on error

echo "🚀 Setting up SpacetimeDB test environment..."

# Check if spacetime CLI is installed
if ! command -v spacetime &> /dev/null; then
    echo "❌ Error: spacetime CLI not found"
    echo "Please install SpacetimeDB from https://spacetimedb.com/install"
    exit 1
fi

echo "✅ SpacetimeDB CLI found"

# Ensure we're logged into local server (creates persistent identity)
echo "🔑 Ensuring local server authentication..."
echo "n" | spacetime list --server http://localhost:3000 > /dev/null 2>&1 || true
echo "✅ Local identity configured"

# Check if SpacetimeDB is running by checking for the process
if pgrep -x "spacetimedb-standalone" > /dev/null; then
    echo "✅ SpacetimeDB already running"
else
    echo "⚠️  SpacetimeDB not running, starting server..."
    spacetime start &
    sleep 3
    echo "✅ SpacetimeDB started"
fi

# Navigate to test module directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEST_MODULE_DIR="$SCRIPT_DIR/../spacetime_test_module"

if [ ! -d "$TEST_MODULE_DIR" ]; then
    echo "❌ Error: Test module directory not found at $TEST_MODULE_DIR"
    exit 1
fi

cd "$TEST_MODULE_DIR"

# Build the test module
echo "🔨 Building test module..."
spacetime build

# Delete existing database if it exists (to start fresh)
echo "🗑️  Cleaning up existing test database..."
spacetime delete notesdb --server http://localhost:3000 --yes 2>/dev/null || {
    echo "⚠️  Could not delete existing database (may be owned by different identity)"
    echo "   If publish fails, manually delete with: spacetime delete notesdb --server http://localhost:3000 --yes"
}

# Publish the test module
echo "📦 Publishing test module to 'notesdb'..."
if ! spacetime publish notesdb --server http://localhost:3000; then
    echo ""
    echo "❌ Publish failed - likely due to identity mismatch"
    echo ""
    echo "To fix this, manually delete the database and re-run setup:"
    echo "  spacetime delete notesdb --server http://localhost:3000 --yes"
    echo "  ./tool/setup_test_db.sh"
    exit 1
fi

# Generate test code from notesdb schema
echo "🔧 Generating test code from notesdb schema..."
cd "$SCRIPT_DIR/.."
dart run spacetimedb:generate \
    -d notesdb \
    -s http://localhost:3000 \
    -o test/generated

if [ $? -ne 0 ]; then
    echo "❌ Code generation failed"
    exit 1
fi
echo "✅ Generated test code in test/generated/"

echo ""
echo "✅ Test environment setup complete!"
echo ""
echo "You can now run tests with:"
echo "  dart test"
echo ""
