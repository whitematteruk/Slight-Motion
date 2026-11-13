import { createApp, createSSRApp } from 'vue'
import App from './App.vue'
import './style.css'

const root = document.querySelector('#app')
const create = root.firstElementChild ? createSSRApp : createApp
create(App).mount(root)
