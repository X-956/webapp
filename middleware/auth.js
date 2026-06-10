const PUBLIC_PATHS = ['/login']

const ROLE_PATHS = {
  admin: [
    '/',
    '/departments',
    '/doctors',
    '/patients',
    '/registrations',
    '/prescriptions',
    '/statistics'
  ],
  doctor: [
    '/',
    '/doctors',
    '/patients',
    '/registrations',
    '/prescriptions',
    '/statistics'
  ],
  readonly: [
    '/',
    '/departments',
    '/doctors',
    '/patients',
    '/registrations',
    '/prescriptions',
    '/statistics'
  ]
}

function pathMatches (currentPath, allowedPath) {
  if (allowedPath === '/') {
    return currentPath === '/'
  }
  return currentPath === allowedPath || currentPath.startsWith(`${allowedPath}/`)
}

export default function ({ store, route, redirect }) {
  const isPublicPath = PUBLIC_PATHS.includes(route.path)
  const isAuthenticated = store.getters['auth/isAuthenticated']

  if (isPublicPath) {
    if (isAuthenticated) {
      return redirect('/')
    }
    return
  }

  if (!isAuthenticated) {
    return redirect('/login')
  }

  const role = store.state.auth.role
  const allowedPaths = ROLE_PATHS[role] || []
  const canAccess = allowedPaths.some(allowedPath => pathMatches(route.path, allowedPath))

  if (!canAccess) {
    return redirect('/')
  }
}
