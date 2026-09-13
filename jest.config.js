const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver'],
    // The preset's own collectCoverageFrom globs every file under lwc/ and then
    // negates only .html and .css, which leaves .js-meta.xml in the set.
    // Istanbul cannot instrument those, and rather than failing, the whole
    // coverage run collapses to an empty report: coverage-final.json is `{}`,
    // every file reads 0%, and the command still exits 0. That makes the
    // coverage gate in CI look green while measuring nothing.
    //
    // Restricting the glob to .js and excluding the test files themselves makes
    // coverage actually report.
    collectCoverageFrom: ['force-app/main/default/lwc/**/*.js', '!force-app/main/default/lwc/**/__tests__/**']
};
