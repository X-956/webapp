<template>
  <div>
    <div class="section-heading">
      <div class="section-title">患者管理</div>
      <div class="section-subtitle">患者列表仅展示普通页面需要的非敏感字段。</div>
    </div>

    <v-card class="clinic-card mb-4" flat>
      <v-card-text>
        <v-form @submit.prevent="fetchPatients">
          <v-row align="center">
            <v-col cols="12" md="7">
              <v-text-field
                v-model="keyword"
                dense
                outlined
                hide-details
                prepend-inner-icon="mdi-magnify"
                label="搜索患者姓名、手机号或身份证号"
              />
            </v-col>
            <v-col cols="12" md="5" class="filter-actions">
              <v-btn color="primary" depressed type="submit">
                <v-icon left>mdi-magnify</v-icon>
                查询
              </v-btn>
              <v-btn text color="primary" @click="resetSearch">重置</v-btn>
            </v-col>
          </v-row>
        </v-form>
      </v-card-text>
    </v-card>

    <v-alert v-if="error" type="error" dense outlined class="mb-4">
      {{ error }}
    </v-alert>

    <v-card class="table-card" flat>
      <v-data-table
        :headers="headers"
        :items="patients"
        :loading="loading"
        loading-text="正在加载患者数据..."
        no-data-text="暂无患者数据"
        :items-per-page="10"
      />
    </v-card>
  </div>
</template>

<script>
export default {
  data () {
    return {
      loading: false,
      error: '',
      keyword: '',
      patients: [],
      headers: [
        { text: '患者ID', value: 'patient_id', width: 100 },
        { text: '姓名', value: 'name' },
        { text: '性别', value: 'gender', width: 90 },
        { text: '出生日期', value: 'dob' },
        { text: '注册时间', value: 'created_at' }
      ]
    }
  },
  head () {
    return { title: '患者管理' }
  },
  mounted () {
    this.fetchPatients()
  },
  methods: {
    async fetchPatients () {
      this.loading = true
      this.error = ''
      const params = {}
      if (this.keyword.trim()) {
        params.keyword = this.keyword.trim()
      }
      try {
        this.patients = await this.$api.$get('/patients', { params })
      } catch (error) {
        this.error = this.apiError(error)
      } finally {
        this.loading = false
      }
    },
    resetSearch () {
      this.keyword = ''
      this.fetchPatients()
    },
    apiError (error) {
      return error.response?.data?.message || error.message || '接口请求失败'
    }
  }
}
</script>

<style scoped>
.filter-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}
</style>
