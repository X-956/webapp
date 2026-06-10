<template>
  <div>
    <div class="section-heading">
      <div class="section-title">统计分析</div>
      <div class="section-subtitle">先用表格展示各科室挂号量和医生接诊排行，便于课程设计截图。</div>
    </div>

    <v-alert v-if="error" type="error" dense outlined class="mb-4">
      {{ error }}
    </v-alert>

    <v-row>
      <v-col cols="12" lg="6">
        <v-card class="table-card" flat>
          <v-card-title>各科室挂号量</v-card-title>
          <v-data-table
            :headers="departmentHeaders"
            :items="departmentStats"
            :loading="loading"
            loading-text="正在加载科室统计..."
            no-data-text="暂无科室统计"
            :items-per-page="10"
          />
        </v-card>
      </v-col>
      <v-col cols="12" lg="6">
        <v-card class="table-card" flat>
          <v-card-title>医生接诊排行</v-card-title>
          <v-data-table
            :headers="doctorHeaders"
            :items="doctorStats"
            :loading="loading"
            loading-text="正在加载医生统计..."
            no-data-text="暂无医生统计"
            :items-per-page="10"
          />
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
      departmentStats: [],
      doctorStats: [],
      departmentHeaders: [
        { text: '科室ID', value: 'department_id', width: 100 },
        { text: '科室名称', value: 'department_name' },
        { text: '挂号量', value: 'registration_count', width: 120 }
      ],
      doctorHeaders: [
        { text: '医生ID', value: 'doctor_id', width: 100 },
        { text: '医生姓名', value: 'doctor_name' },
        { text: '科室名称', value: 'department_name' },
        { text: '接诊量', value: 'registration_count', width: 120 }
      ]
    }
  },
  head () {
    return { title: '统计分析' }
  },
  mounted () {
    this.fetchStatistics()
  },
  methods: {
    async fetchStatistics () {
      this.loading = true
      this.error = ''
      try {
        const [departmentStats, doctorStats] = await Promise.all([
          this.$api.$get('/statistics/departments'),
          this.$api.$get('/statistics/doctors')
        ])
        this.departmentStats = departmentStats
        this.doctorStats = doctorStats
      } catch (error) {
        this.error = this.apiError(error)
      } finally {
        this.loading = false
      }
    },
    apiError (error) {
      return error.response?.data?.message || error.message || '接口请求失败'
    }
  }
}
</script>
