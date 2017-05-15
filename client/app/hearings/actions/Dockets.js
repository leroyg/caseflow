import * as Constants from '../constants/constants';

const incrementCounter = () => ({
  type: Constants.INCREMENT_COUNTER,
  payload: {
    by: 25
  }
});

export default incrementCounter;
