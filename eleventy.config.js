export default function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy({
    media: "media",
    curriculum: "curriculum",
    _redirects: "_redirects",
    "src/css": "css",
  });
  return {
    dir: { input: "src", includes: "_includes", data: "_data", output: "_site" },
    markdownTemplateEngine: "njk",
    htmlTemplateEngine: "njk",
  };
}
