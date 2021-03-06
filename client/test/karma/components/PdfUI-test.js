import React from 'react';
import { expect } from 'chai';
import { shallow } from 'enzyme';
import sinon from 'sinon';

import { PdfUI } from '../../../app/components/PdfUI';

const DOCUMENT_PATH_BASE = '/reader/appeal/reader_id1';

/* eslint-disable no-unused-expressions */
describe('PdfUI', () => {
  context('shallow create PdfUI', () => {
    let wrapper;
    let doc;

    beforeEach(() => {
      doc = {
        filename: 'My PDF',
        id: 3,
        type: 'Form 8',
        receivedAt: '1/2/2017'
      };

      wrapper = shallow(<PdfUI
        doc={doc}
        file="test.pdf"
        filteredDocIds={[3]}
        id="pdf"
        pdfWorker="noworker"
        documentPathBase={DOCUMENT_PATH_BASE}
      />);
    });

    context('.render', () => {
      it('renders the outer div', () => {
        expect(wrapper.find('.cf-pdf-container')).to.have.length(1);
      });

      it('renders the title', () => {
        expect(wrapper.find('Button').find({ name: 'newTab' }).
          children().
          text()).to.eq(doc.type);
      });

      it('does not render the page number when pdf has not been rendered', () => {
        expect(wrapper.text()).to.not.include('Page 1 of 1');
        expect(wrapper.text()).to.include('Loading document');
      });

      it('renders the zoom buttons', () => {
        expect(wrapper.find({ name: 'zoomOut' })).to.have.length(1);
        expect(wrapper.find({ name: 'zoomIn' })).to.have.length(1);
      });

      context('when showClaimsFolderNavigation is true', () => {
        it('renders the back to claims folder button', () => {
          expect(wrapper.find({ name: 'backToClaimsFolder' })).to.have.length(0);

          wrapper.setProps({ showClaimsFolderNavigation: true });
          expect(wrapper.find({ name: 'backToClaimsFolder' })).to.have.length(1);
        });
      });
    });

    context('.onPageChange', () => {
      it('updates the state', () => {
        let currentPage = 2;
        let numPages = 4;

        wrapper.instance().onPageChange(currentPage, numPages);
        expect(wrapper.state('currentPage')).to.equal(currentPage);
        expect(wrapper.state('numPages')).to.equal(numPages);
      });
    });

    context('.zoom', () => {
      it('sets the zoom state', () => {
        let delta = 0.5;
        let currentZoom = wrapper.state('scale');

        wrapper.instance().zoom(delta)();
        expect(wrapper.state('scale')).to.equal(currentZoom + delta);
      });
    });

    context('clicking', () => {
      // I'd like to use spies to make sure zoom is called
      // with the correct values instead of checking state
      // directly. But it proved to be too difficult to
      // spy on a closure generated within client code.
      context('zoomIn', () => {
        it('updates the scale by .3', () => {
          let delta = 0.3;
          let currentZoom = wrapper.state('scale');

          wrapper.find({ name: 'zoomIn' }).simulate('click');
          expect(wrapper.state('scale')).to.equal(currentZoom + delta);
        });
      });

      context('zoomOut', () => {
        it('updates the scale by -.3', () => {
          let delta = -0.3;
          let currentZoom = wrapper.state('scale');

          wrapper.find({ name: 'zoomOut' }).simulate('click');
          expect(wrapper.state('scale')).to.equal(currentZoom + delta);
        });
      });

      context('document name', () => {
        it('tries to open document in new tab', () => {
          let url = `${DOCUMENT_PATH_BASE}/${doc.id}?type=${doc.type}` +
            `&received_at=${doc.receivedAt}&filename=${doc.filename}`;
          let open = sinon.spy(window, 'open');

          wrapper.find('Button').find({ name: 'newTab' }).
            simulate('click');
          expect(open.withArgs(url, '_blank').calledOnce).to.be.true;
        });
      });

      context('backToClaimsFolder', () => {
        it('calls the onShowList prop', () => {
          const mockOnClick = sinon.spy();

          wrapper.setProps({
            showClaimsFolderNavigation: true,
            onShowList: mockOnClick
          });
          wrapper.find({ name: 'backToClaimsFolder' }).simulate('click');

          expect(mockOnClick.calledOnce).to.be.true;
        });
      });
    });
  });
});

/* eslint-enable no-unused-expressions */
