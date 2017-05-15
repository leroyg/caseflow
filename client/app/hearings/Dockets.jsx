import React, { PropTypes } from 'react';
import Table from '../components/Table';
import {formatDate} from '../util/DateUtil';
import moment from 'moment';
// import { hearingsReducers, mapDataToInitialState } from './reducers/index';

export default class HearingDockets extends React.Component {

  getType = (type) => {
    return (type === 'central_office') ? 'CO' : type;
  }

  getStartTime = () => {
    return (
      moment().add(_.random(0, 120), 'minutes').format('LT') + ' EST'
    ).replace('AM', 'a.m.')
    .replace('PM', 'p.m.');
  }

  render() {
  let columns = [
    {
      header: 'Date',
      valueName: 'date'
    },
    {
      header: 'Start Time',
      valueName: 'start_time'
    },
    {
      header: 'Type',
      valueName: 'type'
    },
    {
      header: 'Field Office',
      valueName: 'field_office'
    },
    {
      header: 'Slots',
      align: 'center',
      valueName: 'slots'
    },
    {
      header: 'Scheduled',
      align: 'center',
      valueName: 'scheduled'
    }
  ];

  let rowObjects = this.props.dockets.map((docket) => {
    return {
      date: docket.date,
      start_time: this.getStartTime(),
      type: this.getType(docket.type),
      field_office: `${docket.regional_office.city}, ${docket.regional_office.state} RO`,
      slots: _.random(8, 12),
      scheduled: docket.hearings.length
    };
  });

  let rowClassNames = () => {
    return rowObject.likesSports ? 'cf-success' : '';
  };

    return <div className="cf-hearings cf-app-segment cf-app-segment--alt">
      <h1>Hearings Schedule</h1>
      <Table className="dockets" columns={columns} rowObjects={rowObjects} summary={"WHAT IS THIS?"}/>
    </div>;
  }
}

HearingDockets.propTypes = {
  dockets: PropTypes.arrayOf(PropTypes.object),
/*
  children: PropTypes.node,
  classNames: PropTypes.arrayOf(PropTypes.string),
  disabled: PropTypes.bool,
  id: PropTypes.string,
  linkStyle: PropTypes.bool,
  loading: PropTypes.bool,
  name: PropTypes.string.isRequired,
  onClick: PropTypes.func,
  type: PropTypes.string
*/
};
