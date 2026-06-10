import { API_BASE_URL } from '@/config/api'

export default function ({ $axios, store, redirect }, inject) {
  $axios.setHeader('Content-Type', 'application/json')

  const api = $axios.create({
    headers: {
      common: {
        Accept: 'application/json, text/plain, */*',
        'Content-Type': 'application/json'
      }
    }
  })

  api.onRequest((config) => {
    const token = store.state.auth && store.state.auth.accessToken
    if (token) {
      config.headers = config.headers || {}
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  })

  api.onError((error) => {
    const status = error.response && error.response.status
    const url = (error.config && error.config.url) || ''

    if (process.client && status === 401 && !url.includes('/auth/login')) {
      store.dispatch('auth/clearAuth')
      redirect('/login')
    }

    return Promise.reject(error)
  })

  api.setBaseURL(API_BASE_URL)
  inject('api', api)
  inject('apiBaseUrl', API_BASE_URL)
}
