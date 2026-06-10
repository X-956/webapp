<template>
  <div>
    <div class="section-heading">
      <div class="section-title">处方管理</div>
      <div class="section-subtitle">展示处方与患者、医生、科室的联合查询结果。</div>
    </div>

    <v-alert v-if="error" type="error" dense outlined class="mb-4">
      {{ error }}
    </v-alert>

    <v-card class="table-card" flat>
      <v-data-table
        :headers="headers"
        :items="prescriptions"
        :loading="loading"
        loading-text="正在加载处方记录..."
        no-data-text="暂无处方记录"
        :items-per-page="10"
      >
        <template v-slot:item.total_amount="{ item }">
          ￥{{ Number(item.total_amount || 0).toFixed(2) }}
        </template>
        <template v-slot:item.status="{ item }">
          <v-chip small :color="statusColor(item.status)" text-color="white">
            {{ item.status }}
          </v-chip>
        </template>
      </v-data-table>
    </v-card>
  </div>
</template>

<script>
export default {
  data () {
    return {
      loading: false,
      error: '',
      prescriptions: [],
      headers: [
        { text: '处方ID', value: 'prescription_id', width: 90 },
        { text: '患者姓名', value: 'patient_name' },
        { text: '医生姓名', value: 'doctor_name' },
        { text: '科室名称', value: 'department_name' },
        { text: '诊断', value: 'diagnosis' },
        { text: '药品名称/处方内容', value: 'medicine_name' },
        { text: '金额', value: 'total_amount', width: 110 },
        { text: '状态', value: 'status', width: 110 },
        { text: '开方时间', value: 'created_at' }
      ]
    }
  },
  head () {
    return { title: '处方管理' }
  },
  mounted () {
    this.fetchPrescriptions()
  },
  methods: {
    async fetchPrescriptions () {
      this.loading = true
      this.error = ''
      try {
        this.prescriptions = await this.$api.$get('/prescriptions')
      } catch (error) {
        this.error = this.apiError(error)
      } finally {
        this.loading = false
      }
    },
    statusColor (status) {
      return {
        待缴费: 'deep-orange',
        已缴费: 'blue',
        已取药: 'teal',
        已作废: 'grey'
      }[status] || 'primary'
    },
    apiError (error) {
      return error.response?.data?.message || error.message || '接口请求失败'
    }
  }
}
</script>
