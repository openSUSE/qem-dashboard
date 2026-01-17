import globals from "globals";
import js from "@eslint/js";
import eslintConfigPrettier from "eslint-config-prettier";
import eslintPluginPrettierRecommended from "eslint-plugin-prettier/recommended";
import eslintPluginVue from 'eslint-plugin-vue'
import vuejsAccessibility from 'eslint-plugin-vuejs-accessibility'

// disable import plugin for now (until https://github.com/import-js/eslint-plugin-import/issues/2948
// and https://github.com/import-js/eslint-plugin-import/issues/2556 have been resolved)
// import eslintPlugingImport from 'eslint-plugin-import';

export default [
  js.configs.recommended,
  {
    languageOptions: {
      globals: {
        ...globals.browser,
      },
      sourceType: "module",
    },
  },
  //{
  //  plugins: {
  //    import: eslintPlugingImport,
  //  },
  //  files: ['**/*.js', '**/*.mjs', '**/*.ts'],
  //  rules: {
  //    ...eslintPlugingImport.configs.recommended.rules,
  //    "import/order": [
  //      "error",
  //      {
  //        "groups": ["type", "builtin", ["sibling", "parent"], "index", "object"],
  //        "newlines-between": "never",
  //        alphabetize: {order: "asc", caseInsensitive: true},
  //      },
  //    ],
  //  },
  //},
  eslintConfigPrettier,
  eslintPluginPrettierRecommended,
  ...eslintPluginVue.configs["flat/strongly-recommended"],
  ...vuejsAccessibility.configs["flat/recommended"],
  {
    rules: {
      "vue/max-attributes-per-line": "off",
      "vue/singleline-html-element-content-newline": "off",
      "vue/html-self-closing": "off",
    },
  },
];
