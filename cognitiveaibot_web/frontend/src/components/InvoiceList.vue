<script setup>
import { ref, onMounted } from 'vue'
import { getInvoices } from '../api/chat'

// Stripe invoices for subscription periods. Top-up receipts are emailed by Stripe.
const invoices = ref(null)
const formatMoney = (cents, currency) =>
  (cents / 100).toLocaleString('en-US', { style: 'currency', currency: (currency || 'usd').toUpperCase() })
const formatDate = (d) => new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })

onMounted(async () => {
  invoices.value = await getInvoices()
})
</script>

<template>
  <section v-if="invoices && invoices.length" class="invoices">
    <h2>Invoices</h2>
    <div class="table-wrap">
      <table>
        <thead>
          <tr><th>Date</th><th>Number</th><th class="right">Amount</th><th>Status</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="inv in invoices" :key="inv.id">
            <td>{{ formatDate(inv.created) }}</td>
            <td>{{ inv.number || '—' }}</td>
            <td class="right">{{ formatMoney(inv.amount_cents, inv.currency) }}</td>
            <td class="status">{{ inv.status }}</td>
            <td class="right links">
              <a v-if="inv.url" :href="inv.url" target="_blank" rel="noopener noreferrer">View</a>
              <a v-if="inv.pdf" :href="inv.pdf" target="_blank" rel="noopener noreferrer">PDF</a>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="note">Receipts for one-off top-ups are emailed to you by Stripe.</p>
  </section>
</template>

<style scoped>
.invoices { margin-bottom: 2.25rem; }
h2 { font-size: 1.0625rem; font-weight: 600; color: #e2e8f0; margin-bottom: 0.875rem; }
.table-wrap { overflow-x: auto; border: 1px solid rgba(148, 163, 184, 0.1); border-radius: 12px; }
table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
th { text-align: left; font-weight: 500; color: #64748b; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; padding: 0.625rem 1rem; }
td { padding: 0.55rem 1rem; border-top: 1px solid rgba(148, 163, 184, 0.08); color: #e2e8f0; white-space: nowrap; }
.right { text-align: right; font-variant-numeric: tabular-nums; }
.status { text-transform: capitalize; }
.links a { color: #a5b4fc; margin-left: 0.75rem; }
.note { color: #94a3b8; font-size: 0.8125rem; margin-top: 0.5rem; }
</style>
