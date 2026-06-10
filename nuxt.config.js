
import metajs from './plugins/meta'
const meta = metajs()
export default {
  // Disable server-side rendering (https://go.nuxtjs.dev/ssr-mode)
  // target: 'static',
  telemetry: true,
  ssr: false,
  router: {
    mode: 'hash',
    base: '/',
    routerNameSplitter: '/',
    middleware: ['auth'],
    extendRoutes (routes, resolve) {
      routes.splice(0, routes.length,
        { name: 'login', path: '/login', component: resolve(__dirname, 'pages/login.vue') },
        { name: 'dashboard', path: '/', component: resolve(__dirname, 'pages/index.vue') },
        { name: 'departments', path: '/departments', component: resolve(__dirname, 'pages/departments/index.vue') },
        { name: 'doctors', path: '/doctors', component: resolve(__dirname, 'pages/doctors/index.vue') },
        { name: 'patients', path: '/patients', component: resolve(__dirname, 'pages/patients/index.vue') },
        { name: 'registrations', path: '/registrations', component: resolve(__dirname, 'pages/registrations/index.vue') },
        { name: 'prescriptions', path: '/prescriptions', component: resolve(__dirname, 'pages/prescriptions/index.vue') },
        { name: 'statistics', path: '/statistics', component: resolve(__dirname, 'pages/statistics/index.vue') }
      )
    }
  },
  loadingIndicator: {
    name: 'pulse',
    color: ' #00A756',
    background: '#FAFAFA'
  },

  env: {
    API_BASE_URL: process.env.API_BASE_URL || 'http://127.0.0.1:8001/api'
  },

  // Global page headers (https://go.nuxtjs.dev/config-head)
  head: {
    titleTemplate: '%s - 门诊挂号管理系统',
    title: '医院门诊挂号管理系统',
    meta: [
      ...meta,
      { charset: 'utf-8' },
      /** Chrome, Firefox OS and Opera **/
      { name: 'theme-color', content: '#00A756' },
      /** Windows phone **/
      { name: 'msapplication-navbutton-color', content: '#00A756' },
      /** iOS Safari**/
      { name: 'apple-mobile-web-app-status-bar-style', content: '#00A756' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1.0' },
      { hid: 'description', name: 'description', content: '医院门诊挂号管理系统课程设计前端' },
      { name: 'google-site-verification', content: 'MzkebCr5qPO9ZK3NNdvmWzeeAeMOUx54BMw-J24uSWE' },

      // Twitter meta-data
      { hid: 'twitter:site', name: 'twitter:site', content: 'ospicapp' },
      { hid: 'twitter:card', name: 'twitter:card', content: 'summary_large_image' },
      { hid: 'twitter:image:alt', name: 'twitter:image:alt', content: 'Ospic application' }

    ],
    link: [
      { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' }
    ]
  },

  // Global CSS (https://go.nuxtjs.dev/config-css)
  css: [
    '@/assets/css/styles.css'
  ],

  // Plugins to run before rendering page (https://go.nuxtjs.dev/config-plugins)
  plugins: [
    '~/plugins/vuetify.js',
    '~/plugins/axios',
    '~/plugins/auth.client.js'
    /*
    { src: '~/plugins/localStorage.js', ssr: false }
    */
  ],

  // Course pages use Vuetify directly; disable legacy component auto-scan.
  components: false,

  // Modules for dev and build (recommended) (https://go.nuxtjs.dev/config-modules)
  buildModules: [
    // https://go.nuxtjs.dev/vuetify
    '@nuxtjs/vuetify',
    '@nuxtjs/toast'
  ],

  // Modules (https://go.nuxtjs.dev/config-modules)
  // https://go.nuxtjs.dev/axios
  // https://go.nuxtjs.dev/pwa

  modules: [
    '@nuxtjs/axios',
    '@nuxtjs/pwa',
    '@nuxtjs/toast',
    'nuxt-material-design-icons',
    ['cookie-universal-nuxt', { parseJSON: false }]
  ],

  toast: {
    position: 'bottom-right',
    duration: 4000,
    theme: 'bubble',
    singleton: true,
    iconPack: 'mdi'
  },
  build: {
    /*
     ** You can extend webpack config here
     */
    publicPath: process.env.NODE_ENV === 'production' ? '/assets/' : '',
    extend (_config, _ctx) { },
    postcss: {
      preset: {
        features: {
          'custom-properties': false
        }
      }
    },
    terser: {
      extractComments: false // default was LICENSES
    }
  },
  pwa: {
    manifest: {
      name: '医院门诊挂号管理系统',
      short_name: '门诊挂号',
      color_theme: '#2F4454',
      background_color: '#2F4454',
      lang: 'en',
      useWebmanifestExtension: false
    },
    meta: {
      /* meta options */
      name: 'Ospic Hospital Management System',
      author: 'Ospic',
      description: 'Hospital Management System',
      lang: 'en',
      ogType: 'website',
      ogSiteName: 'Ospic Hms',
      ogTitle: 'Ospic Hospital Management system',
      ogDescription: 'Hospital Management System',
      ogHost: 'https://app.ospic.app/',
      ogImage: 'https://docs.ospic.app/preview.png',
      ogUrl: '',
      twitterCard: 'Ospic',
      twitterSite: 'ospicapp'

    },
    icon: {
      iconSrc: '/static/icon.png'
    }
  },

  // Axios module configuration (https://go.nuxtjs.dev/config-axios)
  axios: {},

  // Build Configuration (https://go.nuxtjs.dev/config-build)

  server: {
    port: 3000,
    host: '0.0.0.0'
  }
}
