module.exports = {
  root: true,
  env: {
    browser: true,
    node: true
  },
  extends: [
    '@nuxtjs/eslint-config'
  ],
  plugins: [
  ],
  // add your custom rules here
  rules: {
    'vue/valid-v-slot': 'off',
    'vue/v-slot-style': 'off',
    'vue/singleline-html-element-content-newline': 'off'
  }
}
