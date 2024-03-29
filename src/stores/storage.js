import { persisted } from 'svelte-persisted-store'
  
export const payTo = persisted('payTo', null)

export const history = persisted('history', {})