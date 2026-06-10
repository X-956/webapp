const STORAGE_KEY = 'hospital_outpatient_auth'

function normalizeAuthPayload (payload) {
  return {
    accessToken: payload.access_token || payload.accessToken || '',
    role: payload.role || '',
    displayName: payload.display_name || payload.displayName || '',
    username: payload.username || '',
    relatedDoctorId: payload.related_doctor_id || payload.relatedDoctorId || null
  }
}

export const namespaced = true

export const state = () => ({
  accessToken: '',
  role: '',
  displayName: '',
  username: '',
  relatedDoctorId: null,
  initialized: false
})

export const getters = {
  isAuthenticated: state => Boolean(state.accessToken),
  currentUser: state => ({
    accessToken: state.accessToken,
    role: state.role,
    displayName: state.displayName,
    username: state.username,
    relatedDoctorId: state.relatedDoctorId
  }),
  canCreateRegistration: state => ['admin', 'doctor'].includes(state.role)
}

export const mutations = {
  SET_AUTH (state, payload) {
    const normalized = normalizeAuthPayload(payload)
    state.accessToken = normalized.accessToken
    state.role = normalized.role
    state.displayName = normalized.displayName
    state.username = normalized.username
    state.relatedDoctorId = normalized.relatedDoctorId
  },
  CLEAR_AUTH (state) {
    state.accessToken = ''
    state.role = ''
    state.displayName = ''
    state.username = ''
    state.relatedDoctorId = null
  },
  SET_INITIALIZED (state, initialized) {
    state.initialized = initialized
  }
}

export const actions = {
  restore ({ commit }) {
    if (!process.client) {
      return
    }

    const raw = window.localStorage.getItem(STORAGE_KEY)
    if (!raw) {
      commit('SET_INITIALIZED', true)
      return
    }

    try {
      commit('SET_AUTH', JSON.parse(raw))
    } catch (_error) {
      window.localStorage.removeItem(STORAGE_KEY)
      commit('CLEAR_AUTH')
    } finally {
      commit('SET_INITIALIZED', true)
    }
  },
  saveAuth ({ commit }, payload) {
    const normalized = normalizeAuthPayload(payload)
    commit('SET_AUTH', normalized)

    if (process.client) {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(normalized))
    }
  },
  clearAuth ({ commit }) {
    commit('CLEAR_AUTH')
    if (process.client) {
      window.localStorage.removeItem(STORAGE_KEY)
    }
  },
  async login ({ dispatch }, payload) {
    const response = await this.$api.$post('/auth/login', payload)
    dispatch('saveAuth', response)
    return response
  },
  async refreshMe ({ state, dispatch }) {
    if (!state.accessToken) {
      return null
    }

    const user = await this.$api.$get('/auth/me')
    dispatch('saveAuth', {
      ...user,
      access_token: state.accessToken
    })
    return user
  }
}
