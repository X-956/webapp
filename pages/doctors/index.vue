<template>
  <div>
    <div class="section-heading">
      <div class="section-title">医生管理</div>
      <div class="section-subtitle">支持按姓名/职称搜索，并按科室筛选医生。</div>
    </div>

    <v-card class="clinic-card mb-4" flat>
      <v-card-text>
        <v-form @submit.prevent="fetchDoctors">
          <v-row align="center">
            <v-col cols="12" md="5">
              <v-text-field
                v-model="filters.keyword"
                dense
                outlined
                hide-details
                prepend-inner-icon="mdi-magnify"
                label="搜索医生姓名、职称、手机号或科室"
              />
            </v-col>
            <v-col cols="12" md="4">
              <v-select
                v-model="filters.department_id"
                :items="departments"
                item-text="department_name"
                item-value="department_id"
                dense
                outlined
                clearable
                hide-details
                label="科室筛选"
              />
            </v-col>
            <v-col cols="12" md="3" class="filter-actions">
              <v-btn color="primary" depressed type="submit">
                <v-icon left>mdi-magnify</v-icon>
                查询
              </v-btn>
              <v-btn text color="primary" @click="resetFilters">重置</v-btn>
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
        :items="doctors"
        :loading="loading"
        loading-text="正在加载医生数据..."
        no-data-text="暂无医生数据"
        :items-per-page="10"
      >
        <template v-slot:item.registration_fee="{ item }">
          ￥{{ Number(item.registration_fee || 0).toFixed(2) }}
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
      doctors: [],
      departments: [],
      filters: {
        keyword: '',
        department_id: null
      },
      headers: [
        { text: '医生ID', value: 'doctor_id', width: 90 },
        { text: '姓名', value: 'name' },
        { text: '性别', value: 'gender', width: 90 },
        { text: '职称', value: 'title' },
        { text: '所属科室', value: 'department_name' },
        { text: '联系电话', value: 'phone' },
        { text: '挂号费', value: 'registration_fee', width: 120 }
      ]
    }
  },
  head () {
    return { title: '医生管理' }
  },
  mounted () {
    this.fetchDepartments()
    this.fetchDoctors()
  },
  methods: {
    async fetchDepartments () {
      try {
        this.departments = await this.$api.$get('/departments')
      } catch (error) {
        this.error = this.apiError(error)
      }
    },
    async fetchDoctors () {
      this.loading = true
      this.error = ''
      const params = {}
      if (this.filters.keyword.trim()) {
        params.keyword = this.filters.keyword.trim()
      }
      if (this.filters.department_id) {
        params.department_id = this.filters.department_id
      }
      try {
        this.doctors = await this.$api.$get('/doctors', { params })
      } catch (error) {
        this.error = this.apiError(error)
      } finally {
        this.loading = false
      }
    },
    resetFilters () {
      this.filters.keyword = ''
      this.filters.department_id = null
      this.fetchDoctors()
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
