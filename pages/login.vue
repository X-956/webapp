<template>
  <v-container fluid class="login-page">
    <v-row class="login-shell" no-gutters>
      <v-col cols="12" md="7" class="login-intro">
        <div class="brand-line">
          <v-avatar color="primary" size="48">
            <v-icon color="white">mdi-hospital-building</v-icon>
          </v-avatar>
          <div>
            <div class="brand-title">医院门诊挂号管理系统</div>
            <div class="brand-subtitle">FastAPI + MySQL 课程设计后台</div>
          </div>
        </div>

        <div class="intro-copy">
          <h1>应用层登录认证</h1>
          <p>按角色进入后台，完成科室、医生、患者、挂号、处方和统计数据管理展示。</p>
        </div>

        <div class="intro-stats">
          <div>
            <strong>JWT</strong>
            <span>Bearer Token</span>
          </div>
          <div>
            <strong>bcrypt</strong>
            <span>密码哈希</span>
          </div>
          <div>
            <strong>RBAC</strong>
            <span>角色权限</span>
          </div>
        </div>
      </v-col>

      <v-col cols="12" md="5" class="login-panel-wrap">
        <v-card class="login-card" flat>
          <v-card-title class="login-card-title">
            登录后台
          </v-card-title>
          <v-card-subtitle>请选择演示账号或输入用户名密码</v-card-subtitle>

          <v-card-text>
            <v-alert v-if="error" type="error" dense outlined class="mb-4">
              {{ error }}
            </v-alert>

            <v-form ref="form" v-model="valid" @submit.prevent="login">
              <v-text-field
                v-model="form.username"
                :rules="[rules.required]"
                dense
                outlined
                label="用户名"
                prepend-inner-icon="mdi-account-outline"
                autocomplete="username"
              />
              <v-text-field
                v-model="form.password"
                :append-icon="showPassword ? 'mdi-eye-off-outline' : 'mdi-eye-outline'"
                :rules="[rules.required]"
                :type="showPassword ? 'text' : 'password'"
                dense
                outlined
                label="密码"
                prepend-inner-icon="mdi-lock-outline"
                autocomplete="current-password"
                @click:append="showPassword = !showPassword"
              />
              <v-btn
                color="primary"
                depressed
                block
                large
                type="submit"
                :loading="loading"
              >
                <v-icon left>mdi-login</v-icon>
                登录
              </v-btn>
            </v-form>

            <v-divider class="my-6" />

            <div class="demo-title">演示账号</div>
            <div class="demo-list">
              <button
                v-for="account in demoAccounts"
                :key="account.username"
                type="button"
                class="demo-account"
                @click="fillDemo(account)"
              >
                <span>
                  <strong>{{ account.username }}</strong>
                  <small>{{ account.roleText }}</small>
                </span>
                <em>{{ account.displayName }}</em>
              </button>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
export default {
  layout: 'login',
  data () {
    return {
      valid: false,
      loading: false,
      showPassword: false,
      error: '',
      form: {
        username: 'admin',
        password: 'Admin123!'
      },
      rules: {
        required: value => Boolean(value) || '必填'
      },
      demoAccounts: [
        {
          username: 'admin',
          password: 'Admin123!',
          roleText: '管理员',
          displayName: '系统管理员'
        },
        {
          username: 'doctor01',
          password: 'Doctor123!',
          roleText: '医生',
          displayName: '张医生'
        },
        {
          username: 'readonly',
          password: 'Readonly123!',
          roleText: '只读',
          displayName: '只读访客'
        }
      ]
    }
  },
  head () {
    return { title: '登录' }
  },
  mounted () {
    if (this.$store.getters['auth/isAuthenticated']) {
      this.$router.push('/')
    }
  },
  methods: {
    fillDemo (account) {
      this.form.username = account.username
      this.form.password = account.password
      this.error = ''
    },
    async login () {
      if (!this.$refs.form.validate()) {
        return
      }

      this.loading = true
      this.error = ''
      try {
        await this.$store.dispatch('auth/login', this.form)
        this.$router.push('/')
      } catch (error) {
        this.error = this.apiError(error)
      } finally {
        this.loading = false
      }
    },
    apiError (error) {
      return error.response?.data?.message || error.message || '登录失败，请稍后重试'
    }
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  padding: 32px;
  background:
    linear-gradient(135deg, rgba(44, 182, 115, 0.12), rgba(8, 127, 140, 0.16)),
    #eef7f6;
}

.login-shell {
  min-height: calc(100vh - 64px);
  overflow: hidden;
  border: 1px solid #d7e8e6;
  border-radius: 8px;
  background: #ffffff;
}

.login-intro {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 48px;
  color: #123f4a;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.88), rgba(238, 247, 246, 0.96)),
    url('~/assets/images/medical_physician_doctor_hands.png') center bottom / cover;
}

.brand-line {
  display: flex;
  align-items: center;
  gap: 14px;
}

.brand-title {
  font-size: 22px;
  font-weight: 800;
}

.brand-subtitle {
  margin-top: 4px;
  color: #607d82;
  font-size: 13px;
}

.intro-copy {
  max-width: 560px;
}

.intro-copy h1 {
  margin-bottom: 16px;
  color: #0f3a45;
  font-size: 44px;
  line-height: 1.15;
}

.intro-copy p {
  max-width: 520px;
  color: #415f66;
  font-size: 17px;
  line-height: 1.8;
}

.intro-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  max-width: 520px;
}

.intro-stats div {
  padding: 16px;
  border: 1px solid #cde3e0;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.86);
}

.intro-stats strong,
.intro-stats span {
  display: block;
}

.intro-stats strong {
  color: #087f8c;
  font-size: 18px;
}

.intro-stats span {
  margin-top: 4px;
  color: #617d82;
  font-size: 13px;
}

.login-panel-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40px;
  background: #f8fcfb;
}

.login-card {
  width: 100%;
  max-width: 420px;
  border: 1px solid #dcebea;
  border-radius: 8px;
}

.login-card-title {
  color: #123f4a;
  font-size: 24px;
  font-weight: 800;
}

.demo-title {
  margin-bottom: 10px;
  color: #123f4a;
  font-weight: 800;
}

.demo-list {
  display: grid;
  gap: 10px;
}

.demo-account {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  min-height: 58px;
  padding: 10px 12px;
  border: 1px solid #d7e8e6;
  border-radius: 8px;
  background: #ffffff;
  color: #20333f;
  cursor: pointer;
  text-align: left;
}

.demo-account:hover {
  border-color: #2cb673;
  background: #edf8f4;
}

.demo-account strong,
.demo-account small {
  display: block;
}

.demo-account small,
.demo-account em {
  color: #66858a;
  font-size: 12px;
  font-style: normal;
}

@media (max-width: 960px) {
  .login-page {
    padding: 16px;
  }

  .login-shell {
    min-height: calc(100vh - 32px);
  }

  .login-intro {
    min-height: 360px;
    padding: 28px;
  }

  .intro-copy h1 {
    font-size: 32px;
  }

  .intro-stats {
    grid-template-columns: 1fr;
  }

  .login-panel-wrap {
    padding: 24px;
  }
}
</style>
