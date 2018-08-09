#!/bin/bash
set -e

USER_ID=${USER_ID:-"www-data"}
GROUP_ID=${GROUP_ID:-$USER_ID}

# NR_APP_NAME and NR_INSTALL_KEY environment variables must be defined
# for NewRelic to be activated.
# Inspired by https://code.tutsplus.com/tutorials/how-to-monitor-docker-based-applications-using-new-relic--cms-24891
if [[ -n $NR_APP_NAME && -n $NR_INSTALL_KEY ]] ; then
    echo "Enabling APM metrics for ${NR_APP_NAME}"
    NR_INSTALL_SILENT=1
    newrelic-install install

    # Update the application name and license key.
    sed -i "s/^newrelic.license = .*/newrelic.license = \"${NR_INSTALL_KEY}\"/" /etc/php/7.2/mods-available/newrelic.ini
    sed -i "s/^newrelic.appname = \"PHP Application\"/newrelic.appname = \"${NR_APP_NAME}\"/" /etc/php/7.2/mods-available/newrelic.ini
    # newrelic-install and debian package conflicts in their way of configuring php. Remove the redundant config file
    rm -f /etc/php/7.2/{fpm,cli}/conf.d/newrelic.ini

    if [ -n $NR_TRANSACTION_TRACER_ENABLED ]; then
        sed -i "s/^;?newrelic.transaction_tracer.enabled = .*/newrelic.transaction_tracer.enabled = \"${NR_TRANSACTION_TRACER_ENABLED}\"/" /etc/php/7.2/mods-available/newrelic.ini
    fi
    if [ -n $NR_TRANSACTION_TRACER_DETAIL ]; then
        sed -i "s/;?newrelic.transaction_tracer.detail = .*/newrelic.transaction_tracer.detail = \"${NR_TRANSACTION_TRACER_DETAIL}\"/" /etc/php/7.2/mods-available/newrelic.ini
    fi
fi

if [[ "$1" == 'php-fpm' || "$1" == 'php-fpm7.2' ]]; then
    shift 1
    echo "Running php-fpm7.2 $@"

    # Set user and group for php-fpm process
    if ! [ "$USER_ID" == 'www-data' ] ; then
        sed -i -e "s/^user = .*/user = $USER_ID/"    /etc/php/7.2/fpm/pool.d/symfony.pool.conf
        sed -i -e "s/^group = .*/group = $GROUP_ID/" /etc/php/7.2/fpm/pool.d/symfony.pool.conf
    fi

    exec php-fpm7.2 "$@"

elif [[ "$1" == 'php' || "$1" == 'php7.2' ]]; then
    shift 1
    echo "Running cli: php7.2 $@"
    exec gosu $USER_ID:$GROUP_ID php7.2 "$@"

else
    echo "Running command: $@"
    exec "$@"

fi
