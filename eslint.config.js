const { defineConfig } = require('eslint/config');
const eslintJs = require('@eslint/js');
const jestPlugin = require('eslint-plugin-jest');
const auraConfig = require('@salesforce/eslint-plugin-aura');
const lwcConfig = require('@salesforce/eslint-config-lwc/recommended');
const globals = require('globals');

module.exports = defineConfig([
    // Salesforce Code Analyzer merges its own bundled eslint-plugin-jest rules
    // onto every file it scans, and that plugin resolves the Jest version from
    // its own node_modules - where jest is absent. Auto-detection then throws
    // and takes the entire ESLint engine down mid-scan, which surfaces in the
    // security-review report as a Critical "UnexpectedEngineError" rather than
    // as a clean result. Pinning the version here applies to every file, so the
    // scan the reviewer runs matches the one run locally.
    {
        settings: {
            jest: { version: 29 }
        }
    },

    // Aura configuration
    {
        files: ['**/aura/**/*.js'],
        extends: [...auraConfig.configs.recommended, ...auraConfig.configs.locker]
    },

    // LWC configuration
    {
        files: ['**/lwc/**/*.js'],
        extends: [lwcConfig]
    },

    // LWC configuration with override for LWC test files
    {
        files: ['**/lwc/**/*.test.js'],
        extends: [lwcConfig],
        rules: {
            '@lwc/lwc/no-unexpected-wire-adapter-usages': 'off'
        },
        languageOptions: {
            globals: {
                ...globals.node
            }
        }
    },

    // Jest mocks configuration
    {
        files: ['**/jest-mocks/**/*.js'],
        languageOptions: {
            sourceType: 'module',
            ecmaVersion: 'latest',
            globals: {
                ...globals.node,
                ...globals.es2021,
                ...jestPlugin.environments.globals.globals
            }
        },
        plugins: {
            eslintJs
        },
        extends: ['eslintJs/recommended']
    }
]);
