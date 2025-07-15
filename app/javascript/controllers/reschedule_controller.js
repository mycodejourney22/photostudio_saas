import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = []

  fetchSlots(event) {
    const date = event.target.value
    const url = `/booking/${window.location.pathname.split('/')[2]}/available_slots?date=${date}`

    fetch(url)
      .then(response => response.json())
      .then(data => {
        const slotSelect = document.getElementById("time-slot-select")
        slotSelect.innerHTML = ""

        if (data.length === 0) {
          slotSelect.innerHTML = `<option disabled>No slots available</option>`
          return
        }

        data.forEach(slot => {
          const option = document.createElement("option")
          option.value = slot.value
          option.text = slot.label
          slotSelect.appendChild(option)
        })
      })
      .catch(error => {
        console.error("Error fetching slots:", error)
      })
  }
}
