<template>
  <div>
    <div class="section-heading">
      <div class="section-title">Dashboard</div>
      <div class="section-subtitle">门诊核心数据总览，统计数据来自 FastAPI 后端。</div>
    </div>

    <v-alert v-if="error" type="error" dense outlined class="mb-4">
      {{ error }}
    </v-alert>

    <v-row>
      <v-col v-for="card in summaryCards" :key="card.key" cols="12" sm="6" lg="2">
        <v-card class="clinic-card summary-card" flat :loading="loading">
          <v-card-text>
            <div class="summary-icon" :style="{ backgroundColor: card.color }">
              <v-icon color="white">{{ card.icon }}</v-icon>
            </div>
            <div class="summary-label">{{ card.title }}</div>
            <div class="summary-value">{{ card.value }}</div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-2">
      <v-col cols="12" md="7">
        <v-card class="clinic-card" flat>
          <v-card-title>系统说明</v-card-title>
          <v-card-text class="intro-text">
            本前端聚焦医院门诊挂号管理系统课程设计：科室、医生、患者、挂号、处方和统计分析。
            当前页面只保留数据库大作业核心业务，所有数据均通过 <strong>{{ apiBaseUrl }}</strong> 获取。
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="12" md="5">
        <v-card class="clinic-card" flat>
          <v-card-title>核心流程</v-card-title>
          <v-card-text>
            <v-timeline dense align-top class="pt-0">
              <v-timeline-item color="primary" small>选择患者、科室和医生</v-timeline-item>
              <v-timeline-item color="teal" small>提交挂号并调用存储过程</v-timeline-item>
              <v-timeline-item color="cyan" small>查看挂号、处方和统计结果</v-timeline-item>
            </v-timeline>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </div>
</template>

<script>
export default {
  data () {
    return {
      loading: false,
      error: '',
      summary: {
        department_count: 0,
        doctor_count: 0,
        patient_count: 0,
        registration_count: 0,
        prescription_amount: 0
      }
    }
  },
  head () {
    return { title: 'Dashboard' }
  },
  computed: {
    apiBaseUrl () {
      return this.$apiBaseUrl
    },
    summaryCards () {
      return [
        {
          key: 'department_count',
          title: '科室数量',
          value: this.summary.department_count,
          icon: 'mdi-domain',
          color: '#087f8c'
        },
        {
          key: 'doctor_count',
          title: '医生数量',
          value: this.summary.doctor_count,
          icon: 'mdi-doctor',
          color: '#159a9c'
        },
        {
          key: 'patient_count',
          title: '患者数量',
          value: this.summary.patient_count,
          icon: 'mdi-account-injury-outline',
          color: '#2cb67d'
        },
        {
          key: 'registration_count',
          title: '挂号数量',
          value: this.summary.registration_count,
          icon: 'mdi-clipboard-plus-outline',
          color: '#2563eb'
        },
        {
          key: 'prescription_amount',
          title: '处方总金额',
          value: this.formatMoney(this.summary.prescription_amount),
          icon: 'mdi-currency-cny',
          color: '#0f766e'
        }
      ]
    }
  },
  mounted () {
    this.fetchSummary()
  },
  methods: {
    async fetchSummary () {
      this.loading = true
      this.error = ''
      try {
        this.summary = await this.$api.$get('/dashboard/summary')
      } catch (error) {
        this.error = this.apiError(error)
      } finally {
        this.loading = false
      }
    },
    formatMoney (value) {
      return `￥${Number(value || 0).toFixed(2)}`
    },
    apiError (error) {
      return error.response?.data?.message || error.message || '接口请求失败'
    }
  }
}
</script>

<style scoped>
.summary-card {
  min-height: 164px;
}

.summary-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 8px;
  margin-bottom: 18px;
}

.summary-label {
  color: #6a8489;
  font-size: 13px;
}

.summary-value {
  margin-top: 6px;
  color: #123f4a;
  font-size: 28px;
  font-weight: 800;
}

.intro-text {
  color: #4d686d;
  line-height: 1.8;
}
</style>
