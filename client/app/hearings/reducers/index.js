import * as Constants from '../constants/constants';
/*
import * as ConfirmCaseDetailsReducers from './ConfirmCaseDetails';
import * as CertificationReducers from './Certification';
*/

/*
* This global reducer is called every time a state change is
* made in the application using `.dispatch`. The state changes implemented here
* are very simple. As they get more complicated and numerous,
* these are conventionally broken out into separate "actions" files
* that would live at client/app/actions/**.js.
*/

// TODO: is this meant to be something like a schema?
// it's too similar to the object in "mapDataToInitialState".
const initialState = {
  counter: 0
};

export const hearingsReducers = function(state = initialState, action = {}) {
  switch (action.type) {

  // ConfirmCaseDetails
  // ==================
  case Constants.INCREMENT_COUNTER:
  console.log("WE GOT HERE");
    return Object.assign({}, state, {
      counter: state.counter + action.payload.by
    });

  default:
    return state;
  }
};
export default hearingsReducers;

export const mapDataToInitialState = function(state) {
  return {
    // TODO alex: fix bug where other representative type won't
    // come down from the server, dagnabbit.
    counter: state.counter
  };
};
