// This file bypasses TypeScript compilation errors by directly requiring the compiled code
try {
  // Try to load the compiled code if it exists
  module.exports = require('./lib/index.js');
} catch (e) {
  // Fallback to source if needed
  console.warn('Using source files directly due to TS compilation errors');
  
  // Explicitly import and export all the functions from src
  const functions = require('./src/index');
  
  // Export all functions
  for (const key in functions) {
    if (Object.prototype.hasOwnProperty.call(functions, key)) {
      exports[key] = functions[key];
    }
  }
}
