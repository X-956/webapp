<template>
  <div>
    <div class="section-heading">
      <div class="section-title">科室管理</div>
      <div class="section-subtitle">查看科室位置、简介和今日剩余号源。</div>
    </div>

    <v-alert v-if="error" type="error" dense outlined class="mb-4">
      {{ error }}
    </v-alert>

    <v-card class="table-card" flat>
      <v-data-table
        :headers="headers"
        :items="departments"
        :loading="loading"
        loading-text="正在加载科室数据..."
        no-data-text="暂无科室数据"
        :items-per-page="10"
      >
        <template v-slot:item.remaining_quota="{ item }">
          <v-chip small color="teal" text-color="white">{{ item.remaining_quota }}</v-chip>
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
      departments: [],
      headers: [
        { text: '科室ID', value: 'department_id', width: 100 },
        { text: '科室名称', value: 'department_name' },
        { text: '科室描述', value: 'description' },
        { text: '位置', value: 'location' },
        { text: '剩余号源', value: 'remaining_quota', width: 120 }
      ]
    }
  },
  head () {
    return { title: '科室管理' }
  },
  mounted () {
    this.fetchDepartments()
  },
  methods: {
    async fetchDepartments () {
      this.loading = true
      this.error = ''
      try {
        this.departments = await this.$api.$get('/departments')
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
