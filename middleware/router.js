export default ({ app, route, from, store, redirect }) => {
  app.router.beforeEach((to, from, next) => {
    next()
  })
  app.router.afterEach((to, from) => {
  })
}
