import React from 'react';
import PropTypes from 'prop-types';
import classnames from 'classnames';
import _ from 'lodash';

/**
 * This component can be used to easily build tables.
 * The required props are:
 * - @columns {array[string]} array of objects that define the properties
 *   of the columns. Possible attributes for each column include:
 *   - @header {string|component} header cell value for the column
 *   - @align {sting} alignment of the column ("left", "right", or "center")
 *   - @valueFunction {function(rowObject)} function that takes `rowObject` as
 *     an argument and returns the value of the cell for that column.
 *   - @valueName {string} if valueFunction is not defined, cell value will use
 *     valueName to pull that attribute from the rowObject.
 *   - @footer {string} footer cell value for the column
 * - @rowObjects {array[object]} array of objects used to build the <tr/> rows
 * - @summary {string} table summary
 *
 * see StyleGuideTables.jsx for usage example.
*/
const alignmentClasses = {
  center: 'cf-txt-c',
  left: 'cf-txt-l',
  right: 'cf-txt-r'
};

const cellClasses = ({ align, cellClass }) => classnames([alignmentClasses[align], cellClass]);

const getColumns = (props) => {
  return _.isFunction(props.columns) ?
    props.columns(props.rowObject) : props.columns;
};

const HeaderRow = (props) => {
  return <thead className={props.headerClassName}>
    <tr>
      {getColumns(props).map((column, columnNumber) =>
        <th scope="col" key={columnNumber} className={cellClasses(column)}>
          {column.header || ''}
        </th>
      )}
    </tr>
  </thead>;
};

const getCellValue = (rowObject, rowId, column) => {
  if (column.valueFunction) {
    return column.valueFunction(rowObject, rowId);
  }
  if (column.valueName) {
    return rowObject[column.valueName];
  }

  return '';
};

const getCellSpan = (rowObject, column) => {
  if (column.span) {
    return column.span(rowObject);
  }

  return 1;
};

class Column extends React.PureComponent {
  // componentWillReceiveProps() {
  //   // console.log(this.props.getCellValue(nextProps.rowObject, nextProps.rowId, nextProps.column) ===
  //   // this.props.getCellValue(this.props.rowObject, this.props.rowId, this.props.column));
  //   console.log("IN COLUMN");
  // }
  // shouldComponentUpdate() {
  //   console.log("SHOULD");
  //   return true;
  // }
  render() {
    const { column, rowObject, footer, rowId } = this.props;
    console.log("HERE");
    //console.log(getCellValue(rowObject, rowId, column));
    return <td
      className={cellClasses(column)}
      colSpan={getCellSpan(rowObject, column)}>
      {footer ?
        column.footer :
        getCellValue(rowObject, rowId, column)}
    </td>;
  }
}

class Row extends React.PureComponent {
  componentWillReceiveProps(nextProps) {
    // console.log("IN ROW");
    // console.log(getColumns(nextProps.rowObject));
    // console.log(getColumns(this.props.rowObject));
    // console.log(_.isEqual(nextProps.rowObject, this.props.rowObject));
  }
  shouldComponentUpdate(nextProps) {
    // console.log(getColumns(nextProps));
    // console.log(getColumns(this.props));
    // console.log(this.props);

    return true;
  }
  render() {
    const props = this.props;
    const rowId = props.footer ? 'footer' : props.rowId;

    return <tr id={`table-row-${rowId}`} className={!props.footer && props.rowClassNames(props.rowObject)}>
      {getColumns(props).map((column, columnNumber) =>
        <Column
          key={columnNumber}
          columnNumber={columnNumber}
          column={column}
          rowObject={props.rowObject}
          rowId={props.rowId}
          footer={props.footer}
        />
      )}
    </tr>;
  }
}

class BodyRows extends React.PureComponent {
  // shouldComponentUpdate(nextProps) {
  //     //console.log("SHOULD");
  //     console.log(getColumns(nextProps));
  //     console.log(getColumns(this.props));
  //     console.log(_.isEqual(nextProps, this.props));

  //     return true;
  //   }

  render() {
    const { rowObjects, bodyClassName, columns, rowClassNames, tbodyRef, id, getKeyForRow } = this.props;

    console.log(getColumns(this.props));

    return <tbody className={bodyClassName} ref={tbodyRef} id={id}>
      {rowObjects.map((object, rowNumber) => {
        const key = getKeyForRow(rowNumber, object);

        return <Row
          rowObject={object}
          columns={columns}
          rowClassNames={rowClassNames}
          key={key}
          rowId={key} />;
      }
      )}
    </tbody>;
  }
}

class FooterRow extends React.PureComponent {
  render() {
    const props = this.props;
    const hasFooters = _.some(props.columns, 'footer');

    return <tfoot>
      {hasFooters && <Row columns={props.columns} footer={true}/>}
    </tfoot>;
  }
}

export default class Table extends React.PureComponent {
  defaultRowClassNames = () => ''

  componentWillReceiveProps(nextProps) {
    console.log("IN ROW");
    console.log(getColumns(nextProps));
    console.log(getColumns(this.props));
    console.log(_.isEqual(getColumns(nextProps).valueFunction, getColumns(this.props).valueFunction));
  }

  render() {
    let {
      columns,
      rowObjects,
      summary,
      headerClassName = '',
      bodyClassName = '',
      rowClassNames = this.defaultRowClassNames,
      getKeyForRow,
      slowReRendersAreOk,
      tbodyId,
      tbodyRef,
      caption,
      id
    } = this.props;

    let keyGetter = getKeyForRow;

    if (!getKeyForRow) {
      keyGetter = _.identity;
      if (!slowReRendersAreOk) {
        console.warn('<Table> props: one of `getKeyForRow` or `slowReRendersAreOk` props must be passed. ' +
          'To learn more about keys, see https://facebook.github.io/react/docs/lists-and-keys.html#keys');
      }
    }

    return <table
              id={id}
              className={`usa-table-borderless cf-table-borderless ${this.props.className}`}
              summary={summary} >

        { caption && <caption className="usa-sr-only">{ caption }</caption> }

        <HeaderRow columns={columns} headerClassName={headerClassName}/>
        <BodyRows
          id={tbodyId}
          tbodyRef={tbodyRef}
          columns={columns}
          getKeyForRow={keyGetter}
          rowObjects={rowObjects}
          bodyClassName={bodyClassName}
          rowClassNames={rowClassNames} />
        <FooterRow columns={columns} />
    </table>;
  }
}

Table.propTypes = {
  tbodyId: PropTypes.string,
  tbodyRef: PropTypes.func,
  columns: PropTypes.oneOfType([
    PropTypes.arrayOf(PropTypes.object),
    PropTypes.func]).isRequired,
  rowObjects: PropTypes.arrayOf(PropTypes.object).isRequired,
  rowClassNames: PropTypes.func,
  keyGetter: PropTypes.func,
  slowReRendersAreOk: PropTypes.bool,
  summary: PropTypes.string,
  headerClassName: PropTypes.string,
  className: PropTypes.string,
  caption: PropTypes.string,
  id: PropTypes.string
};
