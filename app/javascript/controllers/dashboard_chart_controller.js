// // app/javascript/controllers/dashboard_chart_controller.js
// import { Controller } from "@hotwired/stimulus"
// import { Chart, registerables } from "chart.js"
// import 'chartjs-adapter-date-fns'

// Chart.register(...registerables)

// export default class extends Controller {
//   static targets = ["revenueChart"]
//   static values = {
//     revenueData: Array,
//     bookingsData: Array
//   }

//   connect() {
//     this.renderRevenueChart()
//     // this.renderBookingsChart()
//   }

//   renderRevenueChart() {
//     const ctx = this.revenueChartTarget.getContext("2d")
//     const labels = this.revenueDataValue.map(entry => entry.month)
//     const data = this.revenueDataValue.map(entry => entry.revenue)

//     new Chart(ctx, {
//       type: "line",
//       data: {
//         labels: labels,
//         datasets: [{
//           label: "Monthly Revenue",
//           data: data,
//           borderColor: "rgba(99, 102, 241, 1)",
//           backgroundColor: "rgba(99, 102, 241, 0.2)",
//           tension: 0.4
//         }]
//       },
//       options: {
//         responsive: true,
//         maintainAspectRatio: false,
//         cutout: '60%',
//         plugins: {
//           legend: { display: false }
//         },
//         scales: {
//           y: {
//             beginAtZero: true
//           }
//         }
//       }
//     })
//   }

//   // renderBookingsChart() {
//   //   const ctx = this.bookingsChartTarget.getContext("2d")

//   //   new Chart(ctx, {
//   //     type: "doughnut",
//   //     data: {
//   //       labels: ["Completed", "Confirmed", "Pending"],
//   //       datasets: [{
//   //         label: "Bookings",
//   //         data: this.bookingsDataValue,
//   //         backgroundColor: [
//   //           "rgba(34, 197, 94, 0.6)",
//   //           "rgba(59, 130, 246, 0.6)",
//   //           "rgba(251, 191, 36, 0.6)"
//   //         ],
//   //         borderWidth: 1
//   //       }]
//   //     },
//   //     options: {
//   //       responsive: true,
//   //       plugins: {
//   //         legend: {
//   //           position: 'bottom'
//   //         }
//   //       }
//   //     }
//   //   })
//   // }
// }
