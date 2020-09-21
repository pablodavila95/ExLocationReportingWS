//TODO convert to TS
export const push_or_update = (state, new_data) => {
  const new_driver_id = new_data.driver_id;

  if (driver_exists(state, new_driver_id)) {
    const new_state = state.filter(
      (driver) => driver.driver_id !== new_driver_id
    );
    return push_and_sort(new_state, new_data);
  }
  return push_and_sort(state, new_data);
};

const driver_exists = (state, driver_id) => {
  const driver_ids = [];
  state.forEach((driver) => {
    driver_ids.push(driver.driver_id);
  });
  return driver_ids.includes(driver_id);
};

const push_and_sort = (new_state, new_data) => {
  new_state.push(new_data);
  new_state.sort((a, b) => parseInt(a.driver_id) - parseInt(b.driver_id));
  return new_state;
};
