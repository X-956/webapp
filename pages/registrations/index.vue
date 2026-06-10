<template>
  <div>
    <div class="section-heading">
      <div class="section-title">挂号管理</div>
      <div class="section-subtitle">新增挂号调用存储过程，列表展示患者、医生、科室等多表联合数据。</div>
    </div>

    <v-alert v-if="error" type="error" dense outlined class="mb-4">
      {{ error }}
    </v-alert>
    <v-alert v-if="success" type="success" dense outlined class="mb-4">
      {{ success }}
    </v-alert>
    <v-alert v-if="!canCreateRegistration" type="info" dense outlined class="mb-4">
      当前账号为只读角色，仅可查看挂号记录。
    </v-alert>

    <v-row>
      <v-col v-if="canCreateRegistration" cols="12" lg="4">
        <v-card class="clinic-card" flat>
          <v-card-title>新增挂号</v-card-title>
          <v-card-text>
            <v-form ref="form" v-model="formValid" @submit.prevent="submitRegistration">
              <v-select
                v-model="form.patient_id"
                :items="patients"
                item-text="name"
                item-value="patient_id"
                :rules="[rules.required]"
                dense
                outlined
                label="患者"
              />
              <v-select
                v-model="form.department_id"
                :items="departments"
                item-text="department_name"
                item-value="department_id"
                :rules="[rules.required]"
                dense
                outlined
                label="科室"
                @change="syncDoctorDepartment"
              />
              <v-select
                v-model="form.doctor_id"
                :items="availableDoctors"
                :item-text="formatDoctor"
                item-value="doctor_id"
                :rules="[rules.required]"
                dense
                outlined
                label="医生"
              />
              <v-text-field
                v-model="form.visit_date"
                :rules="[rules.required]"
                dense
                outlined
                type="date"
                label="预约就诊日期"
              />
              <v-alert v-if="selectedDoctor" dense text color="primary" class="mb-4">
                挂号费：￥{{ Number(selectedDoctor.registration_fee || 0).toFixed(2) }}
              </v-alert>
              <v-btn
                color="primary"
                depressed
                block
                type="submit"
                :loading="submitting"
              >
                <v-icon left>mdi-clipboard-plus-outline</v-icon>
                提交挂号
              </v-btn>
            </v-form>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" :lg="canCreateRegistration ? 8 : 12">
        <v-card class="table-card" flat>
          <v-data-table
            :headers="headers"
            :items="registrations"
            :loading="loading"
            loading-text="正在加载挂号记录..."
            no-data-text="暂无挂号记录"
            :items-per-page="10"
          >
            <template v-slot:item.reg_time="{ item }">
              {{ formatDateTime(item.reg_time) }}
            </template>
            <template v-slot:item.fee="{ item }">
              ￥{{ Number(item.fee || 0).toFixed(2) }}
            </template>
            <template v-slot:item.status="{ item }">
              <v-chip small :color="statusColor(item.status)" text-color="white">
                {{ item.status }}
              </v-chip>
            </template>
          </v-data-table>
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
      submitting: false,
      formValid: false,
      error: '',
      success: '',
      patients: [],
      departments: [],
      doctors: [],
      registrations: [],
      form: {
        patient_id: null,
        department_id: null,
        doctor_id: null,
        visit_date: new Date().toISOString().slice(0, 10)
      },
      rules: {
        required: value => Boolean(value) || '必填'
      },
      headers: [
        { text: '挂号ID', value: 'registration_id', width: 90 },
        { text: '患者姓名', value: 'patient_name' },
        { text: '医生姓名', value: 'doctor_name' },
        { text: '科室名称', value: 'department_name' },
        { text: '挂号时间', value: 'reg_time' },
        { text: '就诊日期', value: 'visit_date' },
        { text: '费用', value: 'fee', width: 100 },
        { text: '状态', value: 'status', width: 110 }
      ]
    }
  },
  head () {
    return { title: '挂号管理' }
  },
  computed: {
    canCreateRegistration () {
      return this.$store.getters['auth/canCreateRegistration']
    },
    availableDoctors () {
      if (!this.form.department_id) {
        return this.doctors
      }
      return this.doctors.filter(
        doctor => doctor.department_id === this.form.department_id
      )
    },
    selectedDoctor () {
      return this.doctors.find(doctor => doctor.doctor_id === this.form.doctor_id)
    }
  },
  mounted () {
    this.loadPageData()
  },
  methods: {
    async loadPageData () {
      this.loading = true
      this.error = ''
      try {
        const [patients, departments, doctors, registrations] = await Promise.all([
          this.$api.$get('/patients'),
          this.$api.$get('/departments'),
          this.$api.$get('/doctors'),
          this.$api.$get('/registrations')
        ])
        this.patients = patients
        this.departments = departments
        this.doctors = doctors
        this.registrations = registrations
      } catch (error) {
        this.error = this.apiError(error)
      } finally {
        this.loading = false
      }
    },
    async refreshRegistrations () {
      this.registrations = await this.$api.$get('/registrations')
    },
    async submitRegistration () {
      if (!this.canCreateRegistration) {
        this.error = '当前账号无新增挂号权限'
        return
      }
      if (!this.$refs.form.validate()) {
        return
      }
      this.submitting = true
      this.error = ''
      this.success = ''
      try {
        const response = await this.$api.$post('/registrations', this.form)
        this.success = response.message || '挂号成功'
        await Promise.all([
          this.refreshRegistrations(),
          this.refreshDepartments()
        ])
      } catch (error) {
        this.error = this.apiError(error)
      } finally {
        this.submitting = false
      }
    },
    async refreshDepartments () {
      this.departments = await this.$api.$get('/departments')
    },
    syncDoctorDepartment () {
      if (
        this.form.doctor_id &&
        !this.availableDoctors.some(doctor => doctor.doctor_id === this.form.doctor_id)
      ) {
        this.form.doctor_id = null
      }
    },
    formatDoctor (doctor) {
      return `${doctor.name} · ${doctor.title} · ￥${Number(doctor.registration_fee || 0).toFixed(2)}`
    },
    formatDateTime (value) {
      return value ? String(value).replace('T', ' ') : ''
    },
    statusColor (status) {
      return {
        待就诊: 'primary',
        就诊中: 'blue',
        已完成: 'teal',
        已取消: 'grey',
        已过期: 'deep-orange'
      }[status] || 'primary'
    },
    apiError (error) {
      return error.response?.data?.message || error.message || '接口请求失败'
    }
  }
}
</script>
