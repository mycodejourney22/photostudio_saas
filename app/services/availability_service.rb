class AvailabilityService
  BUSINESS_HOURS = {
    start: 9,
    end: 18,
    slot_duration: 60 # minutes
  }.freeze

  def initialize(tenant)
    @tenant = tenant
  end

  def available_slots(date)
    slots = generate_time_slots(date)
    booked_slots = get_booked_slots(date)

    slots.reject { |slot| booked_slots.include?(slot) }
  end

  def available_studios(start_time, end_time)
    @tenant.studios.available_at(start_time, end_time)
  end

  private

  def generate_time_slots(date)
    slots = []
    current_time = date.beginning_of_day + BUSINESS_HOURS[:start].hours
    end_time = date.beginning_of_day + BUSINESS_HOURS[:end].hours

    while current_time < end_time
      slots << current_time
      current_time += BUSINESS_HOURS[:slot_duration].minutes
    end

    slots
  end

  def get_booked_slots(date)
    @tenant.appointments
           .where(scheduled_at: date.beginning_of_day..date.end_of_day)
           .where(status: ['confirmed', 'in_progress'])
           .pluck(:scheduled_at)
  end
end
