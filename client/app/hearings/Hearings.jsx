import React from 'react';
import { BrowserRouter, Route, Redirect } from 'react-router-dom';
import { Provider, connect } from 'react-redux';
import { createStore } from 'redux';

import incrementCounter from './actions/Dockets';

import { hearingsReducers, mapDataToInitialState } from './reducers/index';
import Dockets from './Dockets';

const mapStateToProps = (state) => ({
  counter: state.counter
});

const configureStore = (data) => {
  const initialData = mapDataToInitialState(data);
  const store = createStore(hearingsReducers, initialData);

  console.log("MY STORE", store, new Date());
  console.log("COUNTER IS", store.getState("counter"));
  /*
  store.dispatch({
    type: Constants.INCREMENT_COUNTER,
    payload: {
      by: 5
    }
  });
  */
  store.dispatch(incrementCounter());
  console.log("COUNTER IS", store.getState("counter"));

  if (module.hot) {
    // Enable Webpack hot module replacement for reducers
    module.hot.accept('./reducers/index', () => {
      store.replaceReducer(hearingsReducers);
    });
  }

  return store;
};

const Hearings = ({ hearings }) => {

  return <Provider store={configureStore(hearings = {counter: 0})}>
    <div>
      <Route path="/hearings/dockets"
        component={Dockets}/>
    </div>
  </Provider>;
};

export default Hearings;
