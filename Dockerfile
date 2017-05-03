FROM ruby:2.2.4

RUN apt-get update -qq && apt-get install -y build-essential libaio1 unzip libxml2 libxml2-dev libxslt1-dev alien

# for postgres
RUN apt-get install -y libpq-dev

# for capybara-webkit
RUN apt-get install -y libqt4-webkit libqt4-dev xvfb

# for a JS runtime
RUN apt-get install -y nodejs
RUN apt-get install -y npm

RUN mkdir -p /opt/oracle
RUN wget https://s3-us-gov-west-1.amazonaws.com/shared-s3/dsva-appeals/oracle-instantclient12.1-basic-12.1.0.2.0-1.x86_64.rpm -P /opt/oracle/
RUN wget https://s3-us-gov-west-1.amazonaws.com/shared-s3/dsva-appeals/oracle-instantclient12.1-devel-12.1.0.2.0-1.x86_64.rpm -P /opt/oracle/

# Oracle Client Environment Variables
ENV ORACLE_HOME /usr/lib/oracle/12.1/client64
ENV LD_LIBRARY_PATH $ORACLE_HOME/lib/:$LD_LIBRARY_PATH
ENV NLS_LANG American_America.UTF8
ENV PATH $ORACLE_HOME/bin:$PATH

RUN alien -i /opt/oracle/oracle-instantclient12.1-basic-12.1.0.2.0-1.x86_64.rpm \
  && alien -i /opt/oracle/oracle-instantclient12.1-devel-12.1.0.2.0-1.x86_64.rpm

ENV APP_HOME /caseflow
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile $APP_HOME/Gemfile
ADD Gemfile.lock $APP_HOME/Gemfile.lock
ADD package.json $APP_HOME/package.json

RUN bundle install
RUN npm install

ADD . $APP_HOME