import axios, { AxiosResponse } from 'axios';

interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
}

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/starby-api',
  timeout: 10000
});

// 请求拦截器 - 添加 token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// 响应拦截器
api.interceptors.response.use(
  (response: AxiosResponse<ApiResponse>) => response.data as any,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/starby-admin/login';
    }
    return Promise.reject(error);
  }
);

export default api;
