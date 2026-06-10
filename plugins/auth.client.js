export default async function ({ store }) {
  await store.dispatch('auth/restore')

  if (!store.getters['auth/isAuthenticated']) {
    return
  }

  try {
    await store.dispatch('auth/refreshMe')
  } catch (_error) {
    await store.dispatch('auth/clearAuth')
  }
}
