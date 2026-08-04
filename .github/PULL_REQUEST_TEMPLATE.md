# Pull Request

## Description

Brief description of the changes made in this pull request.

## Type of Change

Please check the type of change your PR introduces:

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update (changes to documentation only)
- [ ] 🔧 Refactoring (code change that neither fixes a bug nor adds a feature)
- [ ] ⚡ Performance improvement (code change that improves performance)
- [ ] 🧪 Test improvement (adding missing tests or correcting existing tests)
- [ ] 🔨 Build/CI changes (changes to build process or CI configuration)
- [ ] 🎨 Code style changes (formatting, missing semicolons, etc.)

## Related Issues

Closes #(issue number)
Fixes #(issue number)
Relates to #(issue number)

## Changes Made

Please describe the changes made in this PR:

- [ ] Added new compression algorithm support
- [ ] Fixed memory leak in decompression
- [ ] Improved error handling
- [ ] Updated documentation
- [ ] Added new configuration options
- [ ] Performance optimizations
- [ ] Other: _describe here_

## Affected Algorithms

Which compression algorithms are affected by this change? (Check all that apply)

- [ ] gzip
- [ ] zlib
- [ ] deflate
- [ ] zstd
- [ ] lz4
- [ ] lzma
- [ ] xz
- [ ] tar.gz
- [ ] zip
- [ ] All algorithms
- [ ] Algorithm-agnostic changes

## Testing

Please describe the testing you've performed:

- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Manual testing completed
- [ ] Performance testing completed (if applicable)
- [ ] Cross-platform testing completed (if applicable)

### Test Results

```
# Paste test output here
zig build test
```

## Performance Impact

If this change affects performance, please provide benchmarks:

- [ ] No performance impact
- [ ] Performance improvement: _describe and provide numbers_
- [ ] Performance regression: _describe, justify, and provide numbers_
- [ ] Performance impact unknown/not measured

## Breaking Changes

If this introduces breaking changes, please describe them:

- [ ] No breaking changes
- [ ] Breaking changes (describe below)

**Breaking change description:**
<!-- Describe what breaks and how users should migrate -->

## Documentation

- [ ] Documentation updated (if needed)
- [ ] API documentation updated (if needed)
- [ ] Examples updated (if needed)
- [ ] CHANGELOG.md updated (if needed)

## Checklist

Please ensure your PR meets the following requirements:

### Code Quality
- [ ] Code follows the project's style guidelines
- [ ] Self-review of code completed
- [ ] Code is properly commented (especially complex logic)
- [ ] No debug code or console logs left in
- [ ] Error handling is appropriate and consistent

### Testing
- [ ] All tests pass locally
- [ ] New tests cover the changes made
- [ ] Edge cases are tested
- [ ] Memory leaks checked (if applicable)

### Documentation
- [ ] Public API changes are documented
- [ ] Code comments explain the "why" not just the "what"
- [ ] Examples are provided for new features
- [ ] Documentation builds without errors

### Compatibility
- [ ] Changes are compatible with Zig 0.16.0+
- [ ] Cross-platform compatibility maintained
- [ ] No new dependencies added without discussion
- [ ] Backward compatibility maintained (or breaking changes documented)

## Additional Notes

Any additional information, context, or screenshots that would be helpful for reviewers:

<!-- 
Examples:
- Implementation decisions and trade-offs
- Alternative approaches considered
- Future improvements planned
- Known limitations
- Screenshots (for UI changes)
-->

## Reviewer Notes

For maintainers reviewing this PR:

- [ ] Code review completed
- [ ] Tests reviewed and adequate
- [ ] Documentation reviewed
- [ ] Performance impact assessed
- [ ] Security implications considered
- [ ] Breaking changes properly documented

---

**Thank you for contributing to Archive.zig!** 🚀

By submitting this pull request, I confirm that my contribution is made under the terms of the MIT license and that I have the right to submit it under this license.