<template>
  <v-app class="clinic-app">
    <v-navigation-drawer app width="248" color="white" class="clinic-drawer">
      <div class="brand">
        <v-avatar color="primary" size="40">
          <v-icon color="white">mdi-hospital-building</v-icon>
        </v-avatar>
        <div>
          <div class="brand-title">门诊挂号管理</div>
          <div class="brand-subtitle">Hospital OPD System</div>
        </div>
      </div>

      <v-list nav dense class="px-3">
        <v-list-item
          v-for="item in visibleNavItems"
          :key="item.to"
          :to="item.to"
          :exact="item.exact"
          class="clinic-nav-item"
          color="primary"
        >
          <v-list-item-icon>
            <v-icon>{{ item.icon }}</v-icon>
          </v-list-item-icon>
          <v-list-item-content>
            <v-list-item-title>{{ item.title }}</v-list-item-title>
          </v-list-item-content>
        </v-list-item>
      </v-list>
    </v-navigation-drawer>

    <v-app-bar app flat color="white" height="64" class="clinic-app-bar">
      <div>
        <div class="page-title">{{ currentTitle }}</div>
        <div class="page-subtitle">数据库课程设计 · FastAPI + MySQL</div>
      </div>
      <v-spacer />
      <div class="app-actions">
        <v-chip color="primary" outlined small class="api-chip">
          <v-icon left small>mdi-lan-connect</v-icon>
          {{ apiBaseUrl }}
        </v-chip>
        <div class="user-summary">
          <v-avatar color="primary" size="34">
            <span class="avatar-text">{{ avatarText }}</span>
          </v-avatar>
          <div class="user-meta">
            <div class="user-name">{{ currentUser.displayName || currentUser.username }}</div>
            <v-chip x-small :color="roleColor" text-color="white">{{ roleText }}</v-chip>
          </div>
          <v-btn icon color="primary" title="退出登录" @click="logout">
            <v-icon>mdi-logout</v-icon>
          </v-btn>
        </div>
      </div>
    </v-app-bar>

    <v-main class="clinic-main">
      <v-container fluid class="pa-6">
        <nuxt />
      </v-container>
    </v-main>
  </v-app>
</template>

<script>
export default {
  data () {
    return {
      navItems: [
        { title: 'Dashboard', icon: 'mdi-view-dashboard-outline', to: '/', exact: true, roles: ['admin', 'doctor', 'readonly'] },
        { title: '科室管理', icon: 'mdi-domain', to: '/departments', roles: ['admin', 'readonly'] },
        { title: '医生管理', icon: 'mdi-doctor', to: '/doctors', roles: ['admin', 'doctor', 'readonly'] },
        { title: '患者管理', icon: 'mdi-account-injury-outline', to: '/patients', roles: ['admin', 'doctor', 'readonly'] },
        { title: '挂号管理', icon: 'mdi-clipboard-plus-outline', to: '/registrations', roles: ['admin', 'doctor', 'readonly'] },
        { title: '处方管理', icon: 'mdi-pill', to: '/prescriptions', roles: ['admin', 'doctor', 'readonly'] },
        { title: '统计分析', icon: 'mdi-chart-box-outline', to: '/statistics', roles: ['admin', 'doctor', 'readonly'] }
      ]
    }
  },
  computed: {
    apiBaseUrl () {
      return this.$apiBaseUrl
    },
    currentUser () {
      return this.$store.getters['auth/currentUser']
    },
    visibleNavItems () {
      return this.navItems.filter(item => item.roles.includes(this.currentUser.role))
    },
    currentTitle () {
      const current = this.navItems.find(item =>
        item.exact ? this.$route.path === item.to : this.$route.path.startsWith(item.to)
      )
      return current ? current.title : '医院门诊挂号管理系统'
    },
    roleText () {
      return {
        admin: '管理员',
        doctor: '医生',
        readonly: '只读'
      }[this.currentUser.role] || '访客'
    },
    roleColor () {
      return {
        admin: 'primary',
        doctor: 'teal',
        readonly: 'blue-grey'
      }[this.currentUser.role] || 'grey'
    },
    avatarText () {
      const name = this.currentUser.displayName || this.currentUser.username || 'U'
      return name.slice(0, 1).toUpperCase()
    }
  },
  methods: {
    async logout () {
      try {
        await this.$api.$post('/auth/logout')
      } catch (_error) {
      } finally {
        await this.$store.dispatch('auth/clearAuth')
        this.$router.push('/login')
      }
    }
  }
}
</script>

<style>
html {
  overflow-y: auto;
}

.clinic-app {
  background: #eef7f6;
  color: #20333f;
}

.clinic-drawer {
  border-right: 1px solid #d8e8e6;
}

.brand {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 84px;
  padding: 20px;
  border-bottom: 1px solid #e3efed;
}

.brand-title {
  font-size: 18px;
  font-weight: 800;
  color: #123f4a;
}

.brand-subtitle,
.page-subtitle {
  font-size: 12px;
  color: #66858a;
}

.clinic-nav-item {
  margin-bottom: 6px;
  border-radius: 8px;
}

.v-list-item--active.clinic-nav-item {
  background: #e4f5f1;
}

.clinic-app-bar {
  border-bottom: 1px solid #d8e8e6;
}

.app-actions {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.api-chip {
  max-width: 280px;
}

.user-summary {
  display: flex;
  align-items: center;
  gap: 8px;
}

.avatar-text {
  color: #ffffff;
  font-size: 14px;
  font-weight: 800;
}

.user-meta {
  min-width: 86px;
}

.user-name {
  max-width: 132px;
  overflow: hidden;
  color: #123f4a;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.page-title {
  font-size: 20px;
  font-weight: 800;
  color: #123f4a;
}

.clinic-main {
  background: linear-gradient(180deg, #f3fbfa 0%, #edf6f5 100%);
}

.section-heading {
  margin-bottom: 16px;
}

.section-title {
  font-size: 22px;
  font-weight: 800;
  color: #123f4a;
}

.section-subtitle {
  margin-top: 4px;
  color: #6a8489;
}

.clinic-card {
  border: 1px solid #dcebea;
  border-radius: 8px;
}

.table-card {
  border: 1px solid #dcebea;
  border-radius: 8px;
  overflow: hidden;
}

@media (max-width: 960px) {
  .api-chip {
    display: none;
  }
}
</style>
