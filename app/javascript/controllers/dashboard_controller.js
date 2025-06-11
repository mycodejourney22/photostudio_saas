import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"
import 'chartjs-adapter-date-fns'

Chart.register(...registerables)

export default class extends Controller {
  static targets = ["revenueChart", "bookingsChart", "statsContainer"]
  static values = {
    revenueData: Array,
    bookingsData: Array,
    updateUrl: String
  }

  connect() {
    this.initializeCharts()
    this.startAutoRefresh()
  }

  disconnect() {
    this.stopAutoRefresh()
    this.destroyCharts()
  }

  initializeCharts() {
    this.createRevenueChart()
    this.createBookingsChart()
  }

  createRevenueChart() {
    if (!this.hasRevenueChartTarget) return

    const ctx = this.revenueChartTarget.getContext('2d')

    this.revenueChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: this.revenueDataValue.map(item => item.month),
        datasets: [{
          label: 'Revenue',
          data: this.revenueDataValue.map(item => item.revenue),
          borderColor: 'rgb(99, 102, 241)',
          backgroundColor: 'rgba(99, 102, 241, 0.1)',
          borderWidth: 2,
          fill: true,
          tension: 0.4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              callback: function(value) {
                return '$' + value.toLocaleString()
              }
            }
          }
        }
      }
    })
  }

  createBookingsChart() {
    if (!this.hasBookingsChartTarget) return

    const ctx = this.bookingsChartTarget.getContext('2d')

    this.bookingsChart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['Completed', 'Confirmed', 'Pending'],
        datasets: [{
          data: this.bookingsDataValue,
          backgroundColor: [
            'rgb(34, 197, 94)',
            'rgb(99, 102, 241)',
            'rgb(251, 191, 36)'
          ],
          borderWidth: 0
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom'
          }
        }
      }
    })
  }

  startAutoRefresh() {
    this.refreshInterval = setInterval(() => {
      this.refreshStats()
    }, 30000) // Refresh every 30 seconds
  }

  stopAutoRefresh() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }
  }

  async refreshStats() {
    try {
      const response = await fetch(this.updateUrlValue, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.updateStatsDisplay(data)
      }
    } catch (error) {
      console.error('Failed to refresh stats:', error)
    }
  }

  updateStatsDisplay(data) {
    // Update stats counters with animation
    const stats = data.data.attributes
    this.animateCounter('[data-stat="today-bookings"]', stats.today_bookings)
    this.animateCounter('[data-stat="week-revenue"]', stats.week_revenue)
    this.animateCounter('[data-stat="active-customers"]', stats.active_customers)
  }

  animateCounter(selector, targetValue) {
    const element = this.element.querySelector(selector)
    if (!element) return

    const currentValue = parseInt(element.textContent.replace(/[^\d]/g, ''))
    const increment = (targetValue - currentValue) / 20
    let current = currentValue

    const animation = setInterval(() => {
      current += increment
      if ((increment > 0 && current >= targetValue) ||
          (increment < 0 && current <= targetValue)) {
        current = targetValue
        clearInterval(animation)
      }

      if (selector.includes('revenue')) {
        element.textContent = '$' + Math.round(current).toLocaleString()
      } else {
        element.textContent = Math.round(current).toLocaleString()
      }
    }, 50)
  }

  destroyCharts() {
    if (this.revenueChart) {
      this.revenueChart.destroy()
    }
    if (this.bookingsChart) {
      this.bookingsChart.destroy()
    }
  }
}
