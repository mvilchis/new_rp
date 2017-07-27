--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.3
-- Dumped by pg_dump version 9.6.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: tiger; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA tiger;


ALTER SCHEMA tiger OWNER TO postgres;

--
-- Name: tiger_data; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA tiger_data;


ALTER SCHEMA tiger_data OWNER TO postgres;

--
-- Name: topology; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA topology;


ALTER SCHEMA topology OWNER TO postgres;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: postgis_tiger_geocoder; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder WITH SCHEMA tiger;


--
-- Name: EXTENSION postgis_tiger_geocoder; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_tiger_geocoder IS 'PostGIS tiger geocoder and reverse geocoder';


--
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


--
-- Name: EXTENSION postgis_topology; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_topology IS 'PostGIS topology spatial types and functions';


SET search_path = public, pg_catalog;

--
-- Name: contact_check_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION contact_check_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.is_test != NEW.is_test THEN
    RAISE EXCEPTION 'Contact.is_test cannot be changed';
  END IF;

  IF NEW.is_test AND (NEW.is_blocked OR NEW.is_stopped) THEN
    RAISE EXCEPTION 'Test contacts cannot opt out or be blocked';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.contact_check_update() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: contacts_contact; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE contacts_contact (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    uuid character varying(36) NOT NULL,
    name character varying(128),
    is_blocked boolean NOT NULL,
    is_test boolean NOT NULL,
    is_stopped boolean NOT NULL,
    language character varying(3),
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE contacts_contact OWNER TO postgres;

--
-- Name: contact_toggle_system_group(contacts_contact, character, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION contact_toggle_system_group(_contact contacts_contact, _group_type character, _add boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  _group_id INT;
BEGIN
  PERFORM contact_toggle_system_group(_contact.id, _contact.org_id, _group_type, _add);
END;
$$;


ALTER FUNCTION public.contact_toggle_system_group(_contact contacts_contact, _group_type character, _add boolean) OWNER TO postgres;

--
-- Name: contact_toggle_system_group(integer, integer, character, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION contact_toggle_system_group(_contact_id integer, _org_id integer, _group_type character, _add boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  _group_id INT;
BEGIN
  -- lookup the group id
  SELECT id INTO STRICT _group_id FROM contacts_contactgroup
  WHERE org_id = _org_id AND group_type = _group_type;

  -- don't do anything if group doesn't exist for some inexplicable reason
  IF _group_id IS NULL THEN
    RETURN;
  END IF;

  IF _add THEN
    BEGIN
      INSERT INTO contacts_contactgroup_contacts (contactgroup_id, contact_id) VALUES (_group_id, _contact_id);
    EXCEPTION WHEN unique_violation THEN
      -- do nothing
    END;
  ELSE
    DELETE FROM contacts_contactgroup_contacts WHERE contactgroup_id = _group_id AND contact_id = _contact_id;
  END IF;
END;
$$;


ALTER FUNCTION public.contact_toggle_system_group(_contact_id integer, _org_id integer, _group_type character, _add boolean) OWNER TO postgres;

--
-- Name: exec(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION exec(text) RETURNS text
    LANGUAGE plpgsql
    AS $_$ BEGIN EXECUTE $1; RETURN $1; END; $_$;


ALTER FUNCTION public.exec(text) OWNER TO postgres;

--
-- Name: msgs_broadcast; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_broadcast (
    id integer NOT NULL,
    recipient_count integer,
    status character varying(1) NOT NULL,
    base_language character varying(4) NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    purged boolean NOT NULL,
    channel_id integer,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL,
    parent_id integer,
    schedule_id integer,
    send_all boolean NOT NULL,
    media hstore,
    text hstore NOT NULL
);


ALTER TABLE msgs_broadcast OWNER TO postgres;

--
-- Name: temba_broadcast_determine_system_label(msgs_broadcast); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_broadcast_determine_system_label(_broadcast msgs_broadcast) RETURNS character
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF _broadcast.is_active AND _broadcast.schedule_id IS NOT NULL THEN
    RETURN 'E';
  END IF;

  RETURN NULL; -- might not match any label
END;
$$;


ALTER FUNCTION public.temba_broadcast_determine_system_label(_broadcast msgs_broadcast) OWNER TO postgres;

--
-- Name: temba_broadcast_on_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_broadcast_on_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  _is_test BOOLEAN;
  _new_label_type CHAR(1);
  _old_label_type CHAR(1);
BEGIN
  -- new broadcast inserted
  IF TG_OP = 'INSERT' THEN
    -- don't update anything for a test broadcast
    IF NEW.recipient_count = 1 THEN
      SELECT c.is_test INTO _is_test FROM contacts_contact c
      INNER JOIN msgs_msg m ON m.contact_id = c.id AND m.broadcast_id = NEW.id;
      IF _is_test = TRUE THEN
        RETURN NULL;
      END IF;
    END IF;

    _new_label_type := temba_broadcast_determine_system_label(NEW);
    IF _new_label_type IS NOT NULL THEN
      PERFORM temba_insert_system_label(NEW.org_id, _new_label_type, 1);
    END IF;

  -- existing broadcast updated
  ELSIF TG_OP = 'UPDATE' THEN
    _old_label_type := temba_broadcast_determine_system_label(OLD);
    _new_label_type := temba_broadcast_determine_system_label(NEW);

    IF _old_label_type IS DISTINCT FROM _new_label_type THEN
      -- if this could be a test broadcast, check it and exit if so
      IF NEW.recipient_count = 1 THEN
        SELECT c.is_test INTO _is_test FROM contacts_contact c
        INNER JOIN msgs_msg m ON m.contact_id = c.id AND m.broadcast_id = NEW.id;
        IF _is_test = TRUE THEN
          RETURN NULL;
        END IF;
      END IF;

      IF _old_label_type IS NOT NULL THEN
        PERFORM temba_insert_system_label(OLD.org_id, _old_label_type, -1);
      END IF;
      IF _new_label_type IS NOT NULL THEN
        PERFORM temba_insert_system_label(NEW.org_id, _new_label_type, 1);
      END IF;
    END IF;

  -- existing broadcast deleted
  ELSIF TG_OP = 'DELETE' THEN
    -- don't update anything for a test broadcast
    IF OLD.recipient_count = 1 THEN
      SELECT c.is_test INTO _is_test FROM contacts_contact c
      INNER JOIN msgs_msg m ON m.contact_id = c.id AND m.broadcast_id = OLD.id;
      IF _is_test = TRUE THEN
        RETURN NULL;
      END IF;
    END IF;

    _old_label_type := temba_broadcast_determine_system_label(OLD);

    IF _old_label_type IS NOT NULL THEN
      PERFORM temba_insert_system_label(OLD.org_id, _old_label_type, 1);
    END IF;

  -- all broadcast deleted
  ELSIF TG_OP = 'TRUNCATE' THEN
    PERFORM temba_reset_system_labels('{"E"}');

  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION public.temba_broadcast_on_change() OWNER TO postgres;

--
-- Name: channels_channelevent; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE channels_channelevent (
    id integer NOT NULL,
    event_type character varying(16) NOT NULL,
    "time" timestamp with time zone NOT NULL,
    duration integer NOT NULL,
    created_on timestamp with time zone NOT NULL,
    is_active boolean NOT NULL,
    channel_id integer NOT NULL,
    contact_id integer NOT NULL,
    contact_urn_id integer,
    org_id integer NOT NULL
);


ALTER TABLE channels_channelevent OWNER TO postgres;

--
-- Name: temba_channelevent_is_call(channels_channelevent); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_channelevent_is_call(_event channels_channelevent) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN _event.event_type IN ('mo_call', 'mo_miss', 'mt_call', 'mt_miss');
END;
$$;


ALTER FUNCTION public.temba_channelevent_is_call(_event channels_channelevent) OWNER TO postgres;

--
-- Name: temba_channelevent_on_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_channelevent_on_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- new event inserted
  IF TG_OP = 'INSERT' THEN
    -- don't update anything for a non-call event or test call
    IF NOT temba_channelevent_is_call(NEW) OR temba_contact_is_test(NEW.contact_id) THEN
      RETURN NULL;
    END IF;

    IF NEW.is_active THEN
      PERFORM temba_insert_system_label(NEW.org_id, 'C', 1);
    END IF;

  -- existing call updated
  ELSIF TG_OP = 'UPDATE' THEN
    -- don't update anything for a non-call event or test call
    IF NOT temba_channelevent_is_call(NEW) OR temba_contact_is_test(NEW.contact_id) THEN
      RETURN NULL;
    END IF;

    -- is being de-activated
    IF OLD.is_active AND NOT NEW.is_active THEN
      PERFORM temba_insert_system_label(NEW.org_id, 'C', -1);
    -- is being re-activated
    ELSIF NOT OLD.is_active AND NEW.is_active THEN
      PERFORM temba_insert_system_label(NEW.org_id, 'C', 1);
    END IF;

  -- existing call deleted
  ELSIF TG_OP = 'DELETE' THEN
    -- don't update anything for a test call
    IF NOT temba_channelevent_is_call(OLD) OR temba_contact_is_test(OLD.contact_id) THEN
      RETURN NULL;
    END IF;

    IF OLD.is_active THEN
      PERFORM temba_insert_system_label(OLD.org_id, 'C', -1);
    END IF;

  -- all calls deleted
  ELSIF TG_OP = 'TRUNCATE' THEN
    PERFORM temba_reset_system_labels('{"C"}');

  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION public.temba_channelevent_on_change() OWNER TO postgres;

--
-- Name: temba_contact_is_test(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_contact_is_test(_contact_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  _is_test BOOLEAN;
BEGIN
  SELECT is_test INTO STRICT _is_test FROM contacts_contact WHERE id = _contact_id;
  RETURN _is_test;
END;
$$;


ALTER FUNCTION public.temba_contact_is_test(_contact_id integer) OWNER TO postgres;

--
-- Name: temba_flow_for_run(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_flow_for_run(_run_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  _flow_id INTEGER;
BEGIN
  SELECT flow_id INTO STRICT _flow_id FROM flows_flowrun WHERE id = _run_id;
  RETURN _flow_id;
END;
$$;


ALTER FUNCTION public.temba_flow_for_run(_run_id integer) OWNER TO postgres;

--
-- Name: temba_flows_contact_is_test(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_flows_contact_is_test(_contact_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  _is_test BOOLEAN;
BEGIN
  SELECT is_test INTO STRICT _is_test FROM contacts_contact WHERE id = _contact_id;
  RETURN _is_test;
END;
$$;


ALTER FUNCTION public.temba_flows_contact_is_test(_contact_id integer) OWNER TO postgres;

--
-- Name: temba_insert_channelcount(integer, character varying, date, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_insert_channelcount(_channel_id integer, _count_type character varying, _count_day date, _count integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
  BEGIN
    INSERT INTO channels_channelcount("channel_id", "count_type", "day", "count", "is_squashed")
      VALUES(_channel_id, _count_type, _count_day, _count, FALSE);
  END;
$$;


ALTER FUNCTION public.temba_insert_channelcount(_channel_id integer, _count_type character varying, _count_day date, _count integer) OWNER TO postgres;

--
-- Name: temba_insert_flownodecount(integer, uuid, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_insert_flownodecount(_flow_id integer, _node_uuid uuid, _count integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
  BEGIN
    INSERT INTO flows_flownodecount("flow_id", "node_uuid", "count", "is_squashed")
      VALUES(_flow_id, _node_uuid, _count, FALSE);
  END;
$$;


ALTER FUNCTION public.temba_insert_flownodecount(_flow_id integer, _node_uuid uuid, _count integer) OWNER TO postgres;

--
-- Name: temba_insert_flowpathcount(integer, uuid, uuid, timestamp with time zone, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_insert_flowpathcount(_flow_id integer, _from_uuid uuid, _to_uuid uuid, _period timestamp with time zone, _count integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
  BEGIN
    INSERT INTO flows_flowpathcount("flow_id", "from_uuid", "to_uuid", "period", "count", "is_squashed")
      VALUES(_flow_id, _from_uuid, _to_uuid, date_trunc('hour', _period), _count, FALSE);
  END;
$$;


ALTER FUNCTION public.temba_insert_flowpathcount(_flow_id integer, _from_uuid uuid, _to_uuid uuid, _period timestamp with time zone, _count integer) OWNER TO postgres;

--
-- Name: temba_insert_flowruncount(integer, character, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_insert_flowruncount(_flow_id integer, _exit_type character, _count integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO flows_flowruncount("flow_id", "exit_type", "count", "is_squashed")
  VALUES(_flow_id, _exit_type, _count, FALSE);
END;
$$;


ALTER FUNCTION public.temba_insert_flowruncount(_flow_id integer, _exit_type character, _count integer) OWNER TO postgres;

--
-- Name: temba_insert_label_count(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_insert_label_count(_label_id integer, _count integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO msgs_labelcount("label_id", "count", "is_squashed") VALUES(_label_id, _count, FALSE);
END;
$$;


ALTER FUNCTION public.temba_insert_label_count(_label_id integer, _count integer) OWNER TO postgres;

--
-- Name: temba_insert_message_label_counts(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_insert_message_label_counts(_msg_id integer, _count integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO msgs_labelcount("label_id", "count", "is_squashed")
  SELECT label_id, _count, FALSE FROM msgs_msg_labels WHERE msgs_msg_labels.msg_id = _msg_id;
END;
$$;


ALTER FUNCTION public.temba_insert_message_label_counts(_msg_id integer, _count integer) OWNER TO postgres;

--
-- Name: temba_insert_system_label(integer, character, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_insert_system_label(_org_id integer, _label_type character, _count integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO msgs_systemlabelcount("org_id", "label_type", "count", "is_squashed") VALUES(_org_id, _label_type, _count, FALSE);
END;
$$;


ALTER FUNCTION public.temba_insert_system_label(_org_id integer, _label_type character, _count integer) OWNER TO postgres;

--
-- Name: temba_insert_topupcredits(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_insert_topupcredits(_topup_id integer, _count integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO orgs_topupcredits("topup_id", "used", "is_squashed") VALUES(_topup_id, _count, FALSE);
END;
$$;


ALTER FUNCTION public.temba_insert_topupcredits(_topup_id integer, _count integer) OWNER TO postgres;

--
-- Name: msgs_msg; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_msg (
    id integer NOT NULL,
    text text NOT NULL,
    priority integer NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone,
    sent_on timestamp with time zone,
    queued_on timestamp with time zone,
    direction character varying(1) NOT NULL,
    status character varying(1) NOT NULL,
    visibility character varying(1) NOT NULL,
    has_template_error boolean NOT NULL,
    msg_type character varying(1),
    msg_count integer NOT NULL,
    error_count integer NOT NULL,
    next_attempt timestamp with time zone NOT NULL,
    external_id character varying(255),
    media character varying(255),
    broadcast_id integer,
    channel_id integer,
    contact_id integer NOT NULL,
    contact_urn_id integer,
    org_id integer NOT NULL,
    response_to_id integer,
    topup_id integer,
    session_id integer
);


ALTER TABLE msgs_msg OWNER TO postgres;

--
-- Name: temba_msg_determine_system_label(msgs_msg); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_msg_determine_system_label(_msg msgs_msg) RETURNS character
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF _msg.direction = 'I' THEN
    IF _msg.visibility = 'V' THEN
      IF _msg.msg_type = 'I' THEN
        RETURN 'I';
      ELSIF _msg.msg_type = 'F' THEN
        RETURN 'W';
      END IF;
    ELSIF _msg.visibility = 'A' THEN
      RETURN 'A';
    END IF;
  ELSE
    IF _msg.VISIBILITY = 'V' THEN
      IF _msg.status = 'P' OR _msg.status = 'Q' THEN
        RETURN 'O';
      ELSIF _msg.status = 'W' OR _msg.status = 'S' OR _msg.status = 'D' THEN
        RETURN 'S';
      ELSIF _msg.status = 'F' THEN
        RETURN 'X';
      END IF;
    END IF;
  END IF;

  RETURN NULL; -- might not match any label
END;
$$;


ALTER FUNCTION public.temba_msg_determine_system_label(_msg msgs_msg) OWNER TO postgres;

--
-- Name: temba_msg_labels_on_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_msg_labels_on_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  is_visible BOOLEAN;
BEGIN
  -- label applied to message
  IF TG_OP = 'INSERT' THEN
    -- is this message visible
    SELECT msgs_msg.visibility = 'V' INTO STRICT is_visible FROM msgs_msg WHERE msgs_msg.id = NEW.msg_id;

    IF is_visible THEN
      PERFORM temba_insert_label_count(NEW.label_id, 1);
    END IF;

  -- label removed from message
  ELSIF TG_OP = 'DELETE' THEN
    -- is this message visible
    SELECT msgs_msg.visibility = 'V' INTO STRICT is_visible FROM msgs_msg WHERE msgs_msg.id = OLD.msg_id;

    IF is_visible THEN
      PERFORM temba_insert_label_count(OLD.label_id, -1);
    END IF;

  -- no more labels for any messages
  ELSIF TG_OP = 'TRUNCATE' THEN
    TRUNCATE msgs_labelcount;

  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION public.temba_msg_labels_on_change() OWNER TO postgres;

--
-- Name: temba_msg_on_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_msg_on_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  _is_test BOOLEAN;
  _new_label_type CHAR(1);
  _old_label_type CHAR(1);
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    -- prevent illegal message states
    IF NEW.direction = 'I' AND NEW.status NOT IN ('P', 'H') THEN
      RAISE EXCEPTION 'Incoming messages can only be PENDING or HANDLED';
    END IF;
    IF NEW.direction = 'O' AND NEW.visibility = 'A' THEN
      RAISE EXCEPTION 'Outgoing messages cannot be archived';
    END IF;
  END IF;

  -- new message inserted
  IF TG_OP = 'INSERT' THEN
    -- don't update anything for a test message
    IF temba_contact_is_test(NEW.contact_id) THEN
      RETURN NULL;
    END IF;

    _new_label_type := temba_msg_determine_system_label(NEW);
    IF _new_label_type IS NOT NULL THEN
      PERFORM temba_insert_system_label(NEW.org_id, _new_label_type, 1);
    END IF;

  -- existing message updated
  ELSIF TG_OP = 'UPDATE' THEN
    _old_label_type := temba_msg_determine_system_label(OLD);
    _new_label_type := temba_msg_determine_system_label(NEW);

    IF _old_label_type IS DISTINCT FROM _new_label_type THEN
      -- don't update anything for a test message
      IF temba_contact_is_test(NEW.contact_id) THEN
        RETURN NULL;
      END IF;

      IF _old_label_type IS NOT NULL THEN
        PERFORM temba_insert_system_label(OLD.org_id, _old_label_type, -1);
      END IF;
      IF _new_label_type IS NOT NULL THEN
        PERFORM temba_insert_system_label(NEW.org_id, _new_label_type, 1);
      END IF;
    END IF;

    -- is being archived or deleted (i.e. no longer included for user labels)
    IF OLD.visibility = 'V' AND NEW.visibility != 'V' THEN
      PERFORM temba_insert_message_label_counts(NEW.id, -1);
    END IF;

    -- is being restored (i.e. now included for user labels)
    IF OLD.visibility != 'V' AND NEW.visibility = 'V' THEN
      PERFORM temba_insert_message_label_counts(NEW.id, 1);
    END IF;

  -- existing message deleted
  ELSIF TG_OP = 'DELETE' THEN
    -- don't update anything for a test message
    IF temba_contact_is_test(OLD.contact_id) THEN
      RETURN NULL;
    END IF;

    _old_label_type := temba_msg_determine_system_label(OLD);

    IF _old_label_type IS NOT NULL THEN
      PERFORM temba_insert_system_label(OLD.org_id, _old_label_type, -1);
    END IF;

  -- all messages deleted
  ELSIF TG_OP = 'TRUNCATE' THEN
    PERFORM temba_reset_system_labels('{"I", "W", "A", "O", "S", "X"}');

  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION public.temba_msg_on_change() OWNER TO postgres;

--
-- Name: temba_reset_system_labels(character[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_reset_system_labels(_label_types character[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  DELETE FROM msgs_systemlabelcount WHERE label_type = ANY(_label_types);
END;
$$;


ALTER FUNCTION public.temba_reset_system_labels(_label_types character[]) OWNER TO postgres;

--
-- Name: flows_flowstep; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowstep (
    id integer NOT NULL,
    step_type character varying(1) NOT NULL,
    step_uuid character varying(36) NOT NULL,
    rule_uuid character varying(36),
    rule_category character varying(36),
    rule_value character varying(640),
    rule_decimal_value numeric(36,8),
    next_uuid character varying(36),
    arrived_on timestamp with time zone NOT NULL,
    left_on timestamp with time zone,
    contact_id integer NOT NULL,
    run_id integer NOT NULL
);


ALTER TABLE flows_flowstep OWNER TO postgres;

--
-- Name: temba_step_from_uuid(flows_flowstep); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_step_from_uuid(_row flows_flowstep) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF _row.rule_uuid IS NOT NULL THEN
    RETURN UUID(_row.rule_uuid);
  END IF;

  RETURN UUID(_row.step_uuid);
END;
$$;


ALTER FUNCTION public.temba_step_from_uuid(_row flows_flowstep) OWNER TO postgres;

--
-- Name: temba_update_channelcount(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_update_channelcount() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  is_test boolean;
BEGIN
  -- Message being updated
  IF TG_OP = 'INSERT' THEN
    -- Return if there is no channel on this message
    IF NEW.channel_id IS NULL THEN
      RETURN NULL;
    END IF;

    -- Find out if this is a test contact
    SELECT contacts_contact.is_test INTO STRICT is_test FROM contacts_contact WHERE id=NEW.contact_id;

    -- Return if it is
    IF is_test THEN
      RETURN NULL;
    END IF;

    -- If this is an incoming message, without message type, then increment that count
    IF NEW.direction = 'I' THEN
      -- This is a voice message, increment that count
      IF NEW.msg_type = 'V' THEN
        PERFORM temba_insert_channelcount(NEW.channel_id, 'IV', NEW.created_on::date, 1);
      -- Otherwise, this is a normal message
      ELSE
        PERFORM temba_insert_channelcount(NEW.channel_id, 'IM', NEW.created_on::date, 1);
      END IF;

    -- This is an outgoing message
    ELSIF NEW.direction = 'O' THEN
      -- This is a voice message, increment that count
      IF NEW.msg_type = 'V' THEN
        PERFORM temba_insert_channelcount(NEW.channel_id, 'OV', NEW.created_on::date, 1);
      -- Otherwise, this is a normal message
      ELSE
        PERFORM temba_insert_channelcount(NEW.channel_id, 'OM', NEW.created_on::date, 1);
      END IF;

    END IF;

  -- Assert that updates aren't happening that we don't approve of
  ELSIF TG_OP = 'UPDATE' THEN
    -- If the direction is changing, blow up
    IF NEW.direction <> OLD.direction THEN
      RAISE EXCEPTION 'Cannot change direction on messages';
    END IF;

    -- Cannot move from IVR to Text, or IVR to Text
    IF (OLD.msg_type <> 'V' AND NEW.msg_type = 'V') OR (OLD.msg_type = 'V' AND NEW.msg_type <> 'V') THEN
      RAISE EXCEPTION 'Cannot change a message from voice to something else or vice versa';
    END IF;

    -- Cannot change created_on
    IF NEW.created_on <> OLD.created_on THEN
      RAISE EXCEPTION 'Cannot change created_on on messages';
    END IF;

  -- Table being cleared, reset all counts
  ELSIF TG_OP = 'TRUNCATE' THEN
    DELETE FROM channels_channel WHERE count_type IN ('IV', 'IM', 'OV', 'OM');
  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION public.temba_update_channelcount() OWNER TO postgres;

--
-- Name: temba_update_channellog_count(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_update_channellog_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- ChannelLog being added
  IF TG_OP = 'INSERT' THEN
    -- Error, increment our error count
    IF NEW.is_error THEN
      PERFORM temba_insert_channelcount(NEW.channel_id, 'LE', NULL::date, 1);
    -- Success, increment that count instead
    ELSE
      PERFORM temba_insert_channelcount(NEW.channel_id, 'LS', NULL::date, 1);
    END IF;

  -- Updating is_error is forbidden
  ELSIF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Cannot update is_error or channel_id on ChannelLog events';

  -- Deleting, decrement our count
  ELSIF TG_OP = 'DELETE' THEN
    -- Error, decrement our error count
    IF OLD.is_error THEN
      PERFORM temba_insert_channelcount(OLD.channel_id, 'LE', NULL::date, -1);
    -- Success, decrement that count instead
    ELSE
      PERFORM temba_insert_channelcount(OLD.channel_id, 'LS', NULL::date, -1);
    END IF;

  -- Table being cleared, reset all counts
  ELSIF TG_OP = 'TRUNCATE' THEN
    DELETE FROM channels_channel WHERE count_type IN ('LE', 'LS');
  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION public.temba_update_channellog_count() OWNER TO postgres;

--
-- Name: temba_update_flowpathcount(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_update_flowpathcount() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE flow_id int;
BEGIN

  IF TG_OP = 'TRUNCATE' THEN
    -- FlowStep table being cleared, reset all counts
    DELETE FROM flows_flownodecount;
    DELETE FROM flows_flowpathcount;

  -- FlowStep being deleted
  ELSIF TG_OP = 'DELETE' THEN

    -- ignore if test contact
    IF temba_contact_is_test(OLD.contact_id) THEN
      RETURN NULL;
    END IF;

    flow_id = temba_flow_for_run(OLD.run_id);

    IF OLD.left_on IS NULL THEN
      PERFORM temba_insert_flownodecount(flow_id, UUID(OLD.step_uuid), -1);
    ELSE
      PERFORM temba_insert_flowpathcount(flow_id, temba_step_from_uuid(OLD), UUID(OLD.next_uuid), OLD.left_on, -1);
    END IF;

  -- FlowStep being added or left_on field updated
  ELSIF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN

    -- ignore if test contact
    IF temba_contact_is_test(NEW.contact_id) THEN
      RETURN NULL;
    END IF;

    flow_id = temba_flow_for_run(NEW.run_id);

    IF NEW.left_on IS NULL THEN
      PERFORM temba_insert_flownodecount(flow_id, UUID(NEW.step_uuid), 1);
    ELSE
      PERFORM temba_insert_flowpathcount(flow_id, temba_step_from_uuid(NEW), UUID(NEW.next_uuid), NEW.left_on, 1);
    END IF;

    IF TG_OP = 'UPDATE' THEN
      IF OLD.left_on IS NULL THEN
        PERFORM temba_insert_flownodecount(flow_id, UUID(OLD.step_uuid), -1);
      ELSE
        PERFORM temba_insert_flowpathcount(flow_id, temba_step_from_uuid(OLD), UUID(OLD.next_uuid), OLD.left_on, -1);
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION public.temba_update_flowpathcount() OWNER TO postgres;

--
-- Name: temba_update_flowruncount(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_update_flowruncount() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Table being cleared, reset all counts
  IF TG_OP = 'TRUNCATE' THEN
    TRUNCATE flows_flowruncounts;
    RETURN NULL;
  END IF;

  -- FlowRun being added
  IF TG_OP = 'INSERT' THEN
     -- Is this a test contact, ignore
     IF temba_contact_is_test(NEW.contact_id) THEN
       RETURN NULL;
     END IF;

    -- Increment appropriate type
    PERFORM temba_insert_flowruncount(NEW.flow_id, NEW.exit_type, 1);

  -- FlowRun being removed
  ELSIF TG_OP = 'DELETE' THEN
     -- Is this a test contact, ignore
     IF temba_contact_is_test(OLD.contact_id) THEN
       RETURN NULL;
     END IF;

    PERFORM temba_insert_flowruncount(OLD.flow_id, OLD.exit_type, -1);

  -- Updating exit type
  ELSIF TG_OP = 'UPDATE' THEN
     -- Is this a test contact, ignore
     IF temba_contact_is_test(NEW.contact_id) THEN
       RETURN NULL;
     END IF;

    PERFORM temba_insert_flowruncount(OLD.flow_id, OLD.exit_type, -1);
    PERFORM temba_insert_flowruncount(NEW.flow_id, NEW.exit_type, 1);
  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION public.temba_update_flowruncount() OWNER TO postgres;

--
-- Name: temba_update_topupcredits(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_update_topupcredits() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Msg is being created
  IF TG_OP = 'INSERT' THEN
    -- If we have a topup, increment our # of used credits
    IF NEW.topup_id IS NOT NULL THEN
      PERFORM temba_insert_topupcredits(NEW.topup_id, 1);
    END IF;

  -- Msg is being updated
  ELSIF TG_OP = 'UPDATE' THEN
    -- If the topup has changed
    IF NEW.topup_id IS DISTINCT FROM OLD.topup_id THEN
      -- If our old topup wasn't null then decrement our used credits on it
      IF OLD.topup_id IS NOT NULL THEN
        PERFORM temba_insert_topupcredits(OLD.topup_id, -1);
      END IF;

      -- if our new topup isn't null, then increment our used credits on it
      IF NEW.topup_id IS NOT NULL THEN
        PERFORM temba_insert_topupcredits(NEW.topup_id, 1);
      END IF;
    END IF;

  -- Msg is being deleted
  ELSIF TG_OP = 'DELETE' THEN
    -- Remove a used credit if this Msg had one assigned
    IF OLD.topup_id IS NOT NULL THEN
      PERFORM temba_insert_topupcredits(OLD.topup_id, -1);
    END IF;
  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION public.temba_update_topupcredits() OWNER TO postgres;

--
-- Name: temba_update_topupcredits_for_debit(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION temba_update_topupcredits_for_debit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Debit is being created
  IF TG_OP = 'INSERT' THEN
    -- If we are an allocation and have a topup, increment our # of used credits
    IF NEW.topup_id IS NOT NULL AND NEW.debit_type = 'A' THEN
      PERFORM temba_insert_topupcredits(NEW.topup_id, NEW.amount);
    END IF;

  -- Debit is being updated
  ELSIF TG_OP = 'UPDATE' THEN
    -- If the topup has changed
    IF NEW.topup_id IS DISTINCT FROM OLD.topup_id AND NEW.debit_type = 'A' THEN
      -- If our old topup wasn't null then decrement our used credits on it
      IF OLD.topup_id IS NOT NULL THEN
        PERFORM temba_insert_topupcredits(OLD.topup_id, OLD.amount);
      END IF;

      -- if our new topup isn't null, then increment our used credits on it
      IF NEW.topup_id IS NOT NULL THEN
        PERFORM temba_insert_topupcredits(NEW.topup_id, NEW.amount);
      END IF;
    END IF;

  -- Debit is being deleted
  ELSIF TG_OP = 'DELETE' THEN
    -- Remove a used credit if this Debit had one assigned
    IF OLD.topup_id IS NOT NULL AND OLD.debit_type = 'A' THEN
      PERFORM temba_insert_topupcredits(OLD.topup_id, OLD.amount);
    END IF;
  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION public.temba_update_topupcredits_for_debit() OWNER TO postgres;

--
-- Name: update_contact_system_groups(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION update_contact_system_groups() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- new contact added
  IF TG_OP = 'INSERT' AND NEW.is_active AND NOT NEW.is_test THEN
    IF NEW.is_blocked THEN
      PERFORM contact_toggle_system_group(NEW, 'B', true);
    END IF;

    IF NEW.is_stopped THEN
      PERFORM contact_toggle_system_group(NEW, 'S', true);
    END IF;

    IF NOT NEW.is_stopped AND NOT NEW.is_blocked THEN
      PERFORM contact_toggle_system_group(NEW, 'A', true);
    END IF;
  END IF;

  -- existing contact updated
  IF TG_OP = 'UPDATE' AND NOT NEW.is_test THEN
    -- do nothing for inactive contacts
    IF NOT OLD.is_active AND NOT NEW.is_active THEN
      RETURN NULL;
    END IF;

    -- is being blocked
    IF NOT OLD.is_blocked AND NEW.is_blocked THEN
      PERFORM contact_toggle_system_group(NEW, 'B', true);
      PERFORM contact_toggle_system_group(NEW, 'A', false);
    END IF;

    -- is being unblocked
    IF OLD.is_blocked AND NOT NEW.is_blocked THEN
      PERFORM contact_toggle_system_group(NEW, 'B', false);
      IF NOT NEW.is_stopped THEN
        PERFORM contact_toggle_system_group(NEW, 'A', true);
      END IF;
    END IF;

    -- they stopped themselves
    IF NOT OLD.is_stopped AND NEW.is_stopped THEN
      PERFORM contact_toggle_system_group(NEW, 'S', true);
      PERFORM contact_toggle_system_group(NEW, 'A', false);
    END IF;

    -- they opted back in
    IF OLD.is_stopped AND NOT NEW.is_stopped THEN
    PERFORM contact_toggle_system_group(NEW, 'S', false);
      IF NOT NEW.is_blocked THEN
        PERFORM contact_toggle_system_group(NEW, 'A', true);
      END IF;
    END IF;

    -- is being released
    IF OLD.is_active AND NOT NEW.is_active THEN
      PERFORM contact_toggle_system_group(NEW, 'A', false);
      PERFORM contact_toggle_system_group(NEW, 'B', false);
      PERFORM contact_toggle_system_group(NEW, 'S', false);
    END IF;

    -- is being unreleased
    IF NOT OLD.is_active AND NEW.is_active THEN
      IF NEW.is_blocked THEN
        PERFORM contact_toggle_system_group(NEW, 'B', true);
      END IF;

      IF NEW.is_stopped THEN
        PERFORM contact_toggle_system_group(NEW, 'S', true);
      END IF;

      IF NOT NEW.is_stopped AND NOT NEW.is_blocked THEN
        PERFORM contact_toggle_system_group(NEW, 'A', true);
      END IF;
    END IF;

  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_contact_system_groups() OWNER TO postgres;

--
-- Name: update_group_count(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION update_group_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  is_test BOOLEAN;
BEGIN
  -- contact being added to group
  IF TG_OP = 'INSERT' THEN
    -- is this a test contact
    SELECT contacts_contact.is_test INTO STRICT is_test FROM contacts_contact WHERE id = NEW.contact_id;

    IF NOT is_test THEN
      INSERT INTO contacts_contactgroupcount("group_id", "count", "is_squashed")
      VALUES(NEW.contactgroup_id, 1, FALSE);
    END IF;

  -- contact being removed from a group
  ELSIF TG_OP = 'DELETE' THEN
    -- is this a test contact
    SELECT contacts_contact.is_test INTO STRICT is_test FROM contacts_contact WHERE id = OLD.contact_id;

    IF NOT is_test THEN
      INSERT INTO contacts_contactgroupcount("group_id", "count", "is_squashed")
      VALUES(OLD.contactgroup_id, -1, FALSE);
    END IF;

  -- table being cleared, clear our counts
  ELSIF TG_OP = 'TRUNCATE' THEN
    TRUNCATE contacts_contactgroupcount;
  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_group_count() OWNER TO postgres;

--
-- Name: airtime_airtimetransfer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE airtime_airtimetransfer (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    status character varying(1) NOT NULL,
    recipient character varying(64) NOT NULL,
    amount double precision NOT NULL,
    denomination character varying(32),
    data text,
    response text,
    message character varying(255),
    channel_id integer,
    contact_id integer NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE airtime_airtimetransfer OWNER TO postgres;

--
-- Name: airtime_airtimetransfer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE airtime_airtimetransfer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE airtime_airtimetransfer_id_seq OWNER TO postgres;

--
-- Name: airtime_airtimetransfer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE airtime_airtimetransfer_id_seq OWNED BY airtime_airtimetransfer.id;


--
-- Name: api_apitoken; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE api_apitoken (
    is_active boolean NOT NULL,
    key character varying(40) NOT NULL,
    created timestamp with time zone NOT NULL,
    org_id integer NOT NULL,
    role_id integer NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE api_apitoken OWNER TO postgres;

--
-- Name: api_resthook; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE api_resthook (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    slug character varying(50) NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE api_resthook OWNER TO postgres;

--
-- Name: api_resthook_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE api_resthook_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE api_resthook_id_seq OWNER TO postgres;

--
-- Name: api_resthook_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE api_resthook_id_seq OWNED BY api_resthook.id;


--
-- Name: api_resthooksubscriber; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE api_resthooksubscriber (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    target_url character varying(200) NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    resthook_id integer NOT NULL
);


ALTER TABLE api_resthooksubscriber OWNER TO postgres;

--
-- Name: api_resthooksubscriber_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE api_resthooksubscriber_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE api_resthooksubscriber_id_seq OWNER TO postgres;

--
-- Name: api_resthooksubscriber_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE api_resthooksubscriber_id_seq OWNED BY api_resthooksubscriber.id;


--
-- Name: api_webhookevent; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE api_webhookevent (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    status character varying(1) NOT NULL,
    event character varying(16) NOT NULL,
    data text NOT NULL,
    try_count integer NOT NULL,
    next_attempt timestamp with time zone,
    action character varying(8) NOT NULL,
    channel_id integer,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL,
    resthook_id integer,
    run_id integer
);


ALTER TABLE api_webhookevent OWNER TO postgres;

--
-- Name: api_webhookevent_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE api_webhookevent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE api_webhookevent_id_seq OWNER TO postgres;

--
-- Name: api_webhookevent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE api_webhookevent_id_seq OWNED BY api_webhookevent.id;


--
-- Name: api_webhookresult; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE api_webhookresult (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    url text,
    data text,
    request text,
    status_code integer NOT NULL,
    message character varying(255) NOT NULL,
    body text,
    created_by_id integer NOT NULL,
    event_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    request_time integer
);


ALTER TABLE api_webhookresult OWNER TO postgres;

--
-- Name: api_webhookresult_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE api_webhookresult_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE api_webhookresult_id_seq OWNER TO postgres;

--
-- Name: api_webhookresult_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE api_webhookresult_id_seq OWNED BY api_webhookresult.id;


--
-- Name: auth_group; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_group (
    id integer NOT NULL,
    name character varying(80) NOT NULL
);


ALTER TABLE auth_group OWNER TO postgres;

--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_group_id_seq OWNER TO postgres;

--
-- Name: auth_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_group_id_seq OWNED BY auth_group.id;


--
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_group_permissions (
    id integer NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE auth_group_permissions OWNER TO postgres;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_group_permissions_id_seq OWNER TO postgres;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_group_permissions_id_seq OWNED BY auth_group_permissions.id;


--
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


ALTER TABLE auth_permission OWNER TO postgres;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_permission_id_seq OWNER TO postgres;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_permission_id_seq OWNED BY auth_permission.id;


--
-- Name: auth_user; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_user (
    id integer NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(254) NOT NULL,
    first_name character varying(30) NOT NULL,
    last_name character varying(30) NOT NULL,
    email character varying(254) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL
);


ALTER TABLE auth_user OWNER TO postgres;

--
-- Name: auth_user_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_user_groups (
    id integer NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


ALTER TABLE auth_user_groups OWNER TO postgres;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_user_groups_id_seq OWNER TO postgres;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_user_groups_id_seq OWNED BY auth_user_groups.id;


--
-- Name: auth_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_user_id_seq OWNER TO postgres;

--
-- Name: auth_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_user_id_seq OWNED BY auth_user.id;


--
-- Name: auth_user_user_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_user_user_permissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE auth_user_user_permissions OWNER TO postgres;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_user_user_permissions_id_seq OWNER TO postgres;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_user_user_permissions_id_seq OWNED BY auth_user_user_permissions.id;


--
-- Name: authtoken_token; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE authtoken_token (
    key character varying(40) NOT NULL,
    created timestamp with time zone NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE authtoken_token OWNER TO postgres;

--
-- Name: campaigns_campaign; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE campaigns_campaign (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    uuid character varying(36) NOT NULL,
    name character varying(255) NOT NULL,
    is_archived boolean NOT NULL,
    created_by_id integer NOT NULL,
    group_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE campaigns_campaign OWNER TO postgres;

--
-- Name: campaigns_campaign_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE campaigns_campaign_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE campaigns_campaign_id_seq OWNER TO postgres;

--
-- Name: campaigns_campaign_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE campaigns_campaign_id_seq OWNED BY campaigns_campaign.id;


--
-- Name: campaigns_campaignevent; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE campaigns_campaignevent (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    uuid character varying(36) NOT NULL,
    "offset" integer NOT NULL,
    unit character varying(1) NOT NULL,
    event_type character varying(1) NOT NULL,
    delivery_hour integer NOT NULL,
    campaign_id integer NOT NULL,
    created_by_id integer NOT NULL,
    flow_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    relative_to_id integer NOT NULL,
    message hstore
);


ALTER TABLE campaigns_campaignevent OWNER TO postgres;

--
-- Name: campaigns_campaignevent_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE campaigns_campaignevent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE campaigns_campaignevent_id_seq OWNER TO postgres;

--
-- Name: campaigns_campaignevent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE campaigns_campaignevent_id_seq OWNED BY campaigns_campaignevent.id;


--
-- Name: campaigns_eventfire; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE campaigns_eventfire (
    id integer NOT NULL,
    scheduled timestamp with time zone NOT NULL,
    fired timestamp with time zone,
    contact_id integer NOT NULL,
    event_id integer NOT NULL
);


ALTER TABLE campaigns_eventfire OWNER TO postgres;

--
-- Name: campaigns_eventfire_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE campaigns_eventfire_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE campaigns_eventfire_id_seq OWNER TO postgres;

--
-- Name: campaigns_eventfire_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE campaigns_eventfire_id_seq OWNED BY campaigns_eventfire.id;


--
-- Name: channels_alert; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE channels_alert (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    alert_type character varying(1) NOT NULL,
    ended_on timestamp with time zone,
    channel_id integer NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    sync_event_id integer
);


ALTER TABLE channels_alert OWNER TO postgres;

--
-- Name: channels_alert_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE channels_alert_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE channels_alert_id_seq OWNER TO postgres;

--
-- Name: channels_alert_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE channels_alert_id_seq OWNED BY channels_alert.id;


--
-- Name: channels_channel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE channels_channel (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    uuid character varying(36) NOT NULL,
    channel_type character varying(3) NOT NULL,
    name character varying(64),
    address character varying(255),
    country character varying(2),
    gcm_id character varying(255),
    claim_code character varying(16),
    secret character varying(64),
    last_seen timestamp with time zone NOT NULL,
    device character varying(255),
    os character varying(255),
    alert_email character varying(254),
    config text,
    scheme character varying(8) NOT NULL,
    role character varying(4) NOT NULL,
    bod text,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer,
    parent_id integer
);


ALTER TABLE channels_channel OWNER TO postgres;

--
-- Name: channels_channel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE channels_channel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE channels_channel_id_seq OWNER TO postgres;

--
-- Name: channels_channel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE channels_channel_id_seq OWNED BY channels_channel.id;


--
-- Name: channels_channelcount; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE channels_channelcount (
    id integer NOT NULL,
    count_type character varying(2) NOT NULL,
    day date,
    count integer NOT NULL,
    channel_id integer NOT NULL,
    is_squashed boolean NOT NULL
);


ALTER TABLE channels_channelcount OWNER TO postgres;

--
-- Name: channels_channelcount_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE channels_channelcount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE channels_channelcount_id_seq OWNER TO postgres;

--
-- Name: channels_channelcount_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE channels_channelcount_id_seq OWNED BY channels_channelcount.id;


--
-- Name: channels_channelevent_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE channels_channelevent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE channels_channelevent_id_seq OWNER TO postgres;

--
-- Name: channels_channelevent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE channels_channelevent_id_seq OWNED BY channels_channelevent.id;


--
-- Name: channels_channellog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE channels_channellog (
    id integer NOT NULL,
    description character varying(255) NOT NULL,
    is_error boolean NOT NULL,
    url text,
    method character varying(16),
    request text,
    response text,
    response_status integer,
    created_on timestamp with time zone NOT NULL,
    request_time integer,
    channel_id integer NOT NULL,
    msg_id integer,
    session_id integer
);


ALTER TABLE channels_channellog OWNER TO postgres;

--
-- Name: channels_channellog_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE channels_channellog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE channels_channellog_id_seq OWNER TO postgres;

--
-- Name: channels_channellog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE channels_channellog_id_seq OWNED BY channels_channellog.id;


--
-- Name: channels_channelsession; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE channels_channelsession (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    external_id character varying(255) NOT NULL,
    status character varying(1) NOT NULL,
    direction character varying(1) NOT NULL,
    started_on timestamp with time zone,
    ended_on timestamp with time zone,
    session_type character varying(1) NOT NULL,
    duration integer,
    channel_id integer NOT NULL,
    contact_id integer NOT NULL,
    contact_urn_id integer NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE channels_channelsession OWNER TO postgres;

--
-- Name: channels_channelsession_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE channels_channelsession_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE channels_channelsession_id_seq OWNER TO postgres;

--
-- Name: channels_channelsession_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE channels_channelsession_id_seq OWNED BY channels_channelsession.id;


--
-- Name: channels_syncevent; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE channels_syncevent (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    power_source character varying(64) NOT NULL,
    power_status character varying(64) NOT NULL,
    power_level integer NOT NULL,
    network_type character varying(128) NOT NULL,
    lifetime integer,
    pending_message_count integer NOT NULL,
    retry_message_count integer NOT NULL,
    incoming_command_count integer NOT NULL,
    outgoing_command_count integer NOT NULL,
    channel_id integer NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL
);


ALTER TABLE channels_syncevent OWNER TO postgres;

--
-- Name: channels_syncevent_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE channels_syncevent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE channels_syncevent_id_seq OWNER TO postgres;

--
-- Name: channels_syncevent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE channels_syncevent_id_seq OWNED BY channels_syncevent.id;


--
-- Name: contacts_contact_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contacts_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE contacts_contact_id_seq OWNER TO postgres;

--
-- Name: contacts_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contacts_contact_id_seq OWNED BY contacts_contact.id;


--
-- Name: contacts_contactfield; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE contacts_contactfield (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    label character varying(36) NOT NULL,
    key character varying(36) NOT NULL,
    value_type character varying(1) NOT NULL,
    show_in_table boolean NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE contacts_contactfield OWNER TO postgres;

--
-- Name: contacts_contactfield_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contacts_contactfield_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE contacts_contactfield_id_seq OWNER TO postgres;

--
-- Name: contacts_contactfield_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contacts_contactfield_id_seq OWNED BY contacts_contactfield.id;


--
-- Name: contacts_contactgroup; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE contacts_contactgroup (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    uuid character varying(36) NOT NULL,
    name character varying(64) NOT NULL,
    group_type character varying(1) NOT NULL,
    query text,
    created_by_id integer NOT NULL,
    import_task_id integer,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE contacts_contactgroup OWNER TO postgres;

--
-- Name: contacts_contactgroup_contacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE contacts_contactgroup_contacts (
    id integer NOT NULL,
    contactgroup_id integer NOT NULL,
    contact_id integer NOT NULL
);


ALTER TABLE contacts_contactgroup_contacts OWNER TO postgres;

--
-- Name: contacts_contactgroup_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contacts_contactgroup_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE contacts_contactgroup_contacts_id_seq OWNER TO postgres;

--
-- Name: contacts_contactgroup_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contacts_contactgroup_contacts_id_seq OWNED BY contacts_contactgroup_contacts.id;


--
-- Name: contacts_contactgroup_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contacts_contactgroup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE contacts_contactgroup_id_seq OWNER TO postgres;

--
-- Name: contacts_contactgroup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contacts_contactgroup_id_seq OWNED BY contacts_contactgroup.id;


--
-- Name: contacts_contactgroup_query_fields; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE contacts_contactgroup_query_fields (
    id integer NOT NULL,
    contactgroup_id integer NOT NULL,
    contactfield_id integer NOT NULL
);


ALTER TABLE contacts_contactgroup_query_fields OWNER TO postgres;

--
-- Name: contacts_contactgroup_query_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contacts_contactgroup_query_fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE contacts_contactgroup_query_fields_id_seq OWNER TO postgres;

--
-- Name: contacts_contactgroup_query_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contacts_contactgroup_query_fields_id_seq OWNED BY contacts_contactgroup_query_fields.id;


--
-- Name: contacts_contactgroupcount; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE contacts_contactgroupcount (
    id integer NOT NULL,
    count integer NOT NULL,
    group_id integer NOT NULL,
    is_squashed boolean NOT NULL
);


ALTER TABLE contacts_contactgroupcount OWNER TO postgres;

--
-- Name: contacts_contactgroupcount_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contacts_contactgroupcount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE contacts_contactgroupcount_id_seq OWNER TO postgres;

--
-- Name: contacts_contactgroupcount_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contacts_contactgroupcount_id_seq OWNED BY contacts_contactgroupcount.id;


--
-- Name: contacts_contacturn; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE contacts_contacturn (
    id integer NOT NULL,
    urn character varying(255) NOT NULL,
    path character varying(255) NOT NULL,
    scheme character varying(128) NOT NULL,
    priority integer NOT NULL,
    channel_id integer,
    contact_id integer,
    org_id integer NOT NULL,
    auth text
);


ALTER TABLE contacts_contacturn OWNER TO postgres;

--
-- Name: contacts_contacturn_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contacts_contacturn_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE contacts_contacturn_id_seq OWNER TO postgres;

--
-- Name: contacts_contacturn_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contacts_contacturn_id_seq OWNED BY contacts_contacturn.id;


--
-- Name: contacts_exportcontactstask; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE contacts_exportcontactstask (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    uuid character varying(36) NOT NULL,
    created_by_id integer NOT NULL,
    group_id integer,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL,
    status character varying(1) NOT NULL,
    search text
);


ALTER TABLE contacts_exportcontactstask OWNER TO postgres;

--
-- Name: contacts_exportcontactstask_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contacts_exportcontactstask_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE contacts_exportcontactstask_id_seq OWNER TO postgres;

--
-- Name: contacts_exportcontactstask_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contacts_exportcontactstask_id_seq OWNED BY contacts_exportcontactstask.id;


--
-- Name: csv_imports_importtask; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE csv_imports_importtask (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    csv_file character varying(100) NOT NULL,
    model_class character varying(255) NOT NULL,
    import_params text,
    import_log text NOT NULL,
    import_results text,
    task_id character varying(64),
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    task_status character varying(32) NOT NULL
);


ALTER TABLE csv_imports_importtask OWNER TO postgres;

--
-- Name: csv_imports_importtask_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE csv_imports_importtask_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE csv_imports_importtask_id_seq OWNER TO postgres;

--
-- Name: csv_imports_importtask_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE csv_imports_importtask_id_seq OWNED BY csv_imports_importtask.id;


--
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


ALTER TABLE django_content_type OWNER TO postgres;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE django_content_type_id_seq OWNER TO postgres;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE django_content_type_id_seq OWNED BY django_content_type.id;


--
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE django_migrations (
    id integer NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


ALTER TABLE django_migrations OWNER TO postgres;

--
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE django_migrations_id_seq OWNER TO postgres;

--
-- Name: django_migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE django_migrations_id_seq OWNED BY django_migrations.id;


--
-- Name: django_session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


ALTER TABLE django_session OWNER TO postgres;

--
-- Name: django_site; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE django_site (
    id integer NOT NULL,
    domain character varying(100) NOT NULL,
    name character varying(50) NOT NULL
);


ALTER TABLE django_site OWNER TO postgres;

--
-- Name: django_site_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE django_site_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE django_site_id_seq OWNER TO postgres;

--
-- Name: django_site_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE django_site_id_seq OWNED BY django_site.id;


--
-- Name: flows_actionlog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_actionlog (
    id integer NOT NULL,
    text text NOT NULL,
    level character varying(1) NOT NULL,
    created_on timestamp with time zone NOT NULL,
    run_id integer NOT NULL
);


ALTER TABLE flows_actionlog OWNER TO postgres;

--
-- Name: flows_actionlog_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_actionlog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_actionlog_id_seq OWNER TO postgres;

--
-- Name: flows_actionlog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_actionlog_id_seq OWNED BY flows_actionlog.id;


--
-- Name: flows_actionset; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_actionset (
    id integer NOT NULL,
    uuid character varying(36) NOT NULL,
    destination character varying(36),
    destination_type character varying(1),
    actions text NOT NULL,
    x integer NOT NULL,
    y integer NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    flow_id integer NOT NULL
);


ALTER TABLE flows_actionset OWNER TO postgres;

--
-- Name: flows_actionset_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_actionset_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_actionset_id_seq OWNER TO postgres;

--
-- Name: flows_actionset_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_actionset_id_seq OWNED BY flows_actionset.id;


--
-- Name: flows_exportflowresultstask; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_exportflowresultstask (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    uuid character varying(36) NOT NULL,
    config text,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL,
    status character varying(1) NOT NULL
);


ALTER TABLE flows_exportflowresultstask OWNER TO postgres;

--
-- Name: flows_exportflowresultstask_flows; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_exportflowresultstask_flows (
    id integer NOT NULL,
    exportflowresultstask_id integer NOT NULL,
    flow_id integer NOT NULL
);


ALTER TABLE flows_exportflowresultstask_flows OWNER TO postgres;

--
-- Name: flows_exportflowresultstask_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_exportflowresultstask_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_exportflowresultstask_flows_id_seq OWNER TO postgres;

--
-- Name: flows_exportflowresultstask_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_exportflowresultstask_flows_id_seq OWNED BY flows_exportflowresultstask_flows.id;


--
-- Name: flows_exportflowresultstask_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_exportflowresultstask_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_exportflowresultstask_id_seq OWNER TO postgres;

--
-- Name: flows_exportflowresultstask_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_exportflowresultstask_id_seq OWNED BY flows_exportflowresultstask.id;


--
-- Name: flows_flow; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flow (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    uuid character varying(36) NOT NULL,
    name character varying(64) NOT NULL,
    entry_uuid character varying(36),
    entry_type character varying(1),
    is_archived boolean NOT NULL,
    flow_type character varying(1) NOT NULL,
    metadata text,
    expires_after_minutes integer NOT NULL,
    ignore_triggers boolean NOT NULL,
    saved_on timestamp with time zone NOT NULL,
    base_language character varying(4),
    version_number integer NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL,
    saved_by_id integer NOT NULL
);


ALTER TABLE flows_flow OWNER TO postgres;

--
-- Name: flows_flow_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flow_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flow_id_seq OWNER TO postgres;

--
-- Name: flows_flow_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flow_id_seq OWNED BY flows_flow.id;


--
-- Name: flows_flow_labels; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flow_labels (
    id integer NOT NULL,
    flow_id integer NOT NULL,
    flowlabel_id integer NOT NULL
);


ALTER TABLE flows_flow_labels OWNER TO postgres;

--
-- Name: flows_flow_labels_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flow_labels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flow_labels_id_seq OWNER TO postgres;

--
-- Name: flows_flow_labels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flow_labels_id_seq OWNED BY flows_flow_labels.id;


--
-- Name: flows_flowlabel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowlabel (
    id integer NOT NULL,
    uuid character varying(36) NOT NULL,
    name character varying(64) NOT NULL,
    org_id integer NOT NULL,
    parent_id integer
);


ALTER TABLE flows_flowlabel OWNER TO postgres;

--
-- Name: flows_flowlabel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowlabel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowlabel_id_seq OWNER TO postgres;

--
-- Name: flows_flowlabel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowlabel_id_seq OWNED BY flows_flowlabel.id;


--
-- Name: flows_flownodecount; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flownodecount (
    id integer NOT NULL,
    is_squashed boolean NOT NULL,
    node_uuid uuid NOT NULL,
    count integer NOT NULL,
    flow_id integer NOT NULL
);


ALTER TABLE flows_flownodecount OWNER TO postgres;

--
-- Name: flows_flownodecount_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flownodecount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flownodecount_id_seq OWNER TO postgres;

--
-- Name: flows_flownodecount_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flownodecount_id_seq OWNED BY flows_flownodecount.id;


--
-- Name: flows_flowpathcount; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowpathcount (
    id integer NOT NULL,
    from_uuid uuid NOT NULL,
    to_uuid uuid,
    period timestamp with time zone NOT NULL,
    count integer NOT NULL,
    flow_id integer NOT NULL,
    is_squashed boolean NOT NULL
);


ALTER TABLE flows_flowpathcount OWNER TO postgres;

--
-- Name: flows_flowpathcount_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowpathcount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowpathcount_id_seq OWNER TO postgres;

--
-- Name: flows_flowpathcount_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowpathcount_id_seq OWNED BY flows_flowpathcount.id;


--
-- Name: flows_flowpathrecentstep; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowpathrecentstep (
    id integer NOT NULL,
    from_uuid uuid NOT NULL,
    to_uuid uuid NOT NULL,
    left_on timestamp with time zone NOT NULL,
    step_id integer NOT NULL
);


ALTER TABLE flows_flowpathrecentstep OWNER TO postgres;

--
-- Name: flows_flowpathrecentstep_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowpathrecentstep_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowpathrecentstep_id_seq OWNER TO postgres;

--
-- Name: flows_flowpathrecentstep_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowpathrecentstep_id_seq OWNED BY flows_flowpathrecentstep.id;


--
-- Name: flows_flowrevision; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowrevision (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    definition text NOT NULL,
    spec_version integer NOT NULL,
    revision integer,
    created_by_id integer NOT NULL,
    flow_id integer NOT NULL,
    modified_by_id integer NOT NULL
);


ALTER TABLE flows_flowrevision OWNER TO postgres;

--
-- Name: flows_flowrevision_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowrevision_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowrevision_id_seq OWNER TO postgres;

--
-- Name: flows_flowrevision_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowrevision_id_seq OWNED BY flows_flowrevision.id;


--
-- Name: flows_flowrun; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowrun (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    fields text,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    exited_on timestamp with time zone,
    exit_type character varying(1),
    expires_on timestamp with time zone,
    timeout_on timestamp with time zone,
    responded boolean NOT NULL,
    contact_id integer NOT NULL,
    flow_id integer NOT NULL,
    org_id integer NOT NULL,
    parent_id integer,
    session_id integer,
    start_id integer,
    submitted_by_id integer
);


ALTER TABLE flows_flowrun OWNER TO postgres;

--
-- Name: flows_flowrun_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowrun_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowrun_id_seq OWNER TO postgres;

--
-- Name: flows_flowrun_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowrun_id_seq OWNED BY flows_flowrun.id;


--
-- Name: flows_flowruncount; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowruncount (
    id integer NOT NULL,
    exit_type character varying(1),
    count integer NOT NULL,
    flow_id integer NOT NULL,
    is_squashed boolean NOT NULL
);


ALTER TABLE flows_flowruncount OWNER TO postgres;

--
-- Name: flows_flowruncount_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowruncount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowruncount_id_seq OWNER TO postgres;

--
-- Name: flows_flowruncount_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowruncount_id_seq OWNED BY flows_flowruncount.id;


--
-- Name: flows_flowstart; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowstart (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    restart_participants boolean NOT NULL,
    contact_count integer NOT NULL,
    status character varying(1) NOT NULL,
    extra text,
    created_by_id integer NOT NULL,
    flow_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    include_active boolean NOT NULL
);


ALTER TABLE flows_flowstart OWNER TO postgres;

--
-- Name: flows_flowstart_contacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowstart_contacts (
    id integer NOT NULL,
    flowstart_id integer NOT NULL,
    contact_id integer NOT NULL
);


ALTER TABLE flows_flowstart_contacts OWNER TO postgres;

--
-- Name: flows_flowstart_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowstart_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowstart_contacts_id_seq OWNER TO postgres;

--
-- Name: flows_flowstart_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowstart_contacts_id_seq OWNED BY flows_flowstart_contacts.id;


--
-- Name: flows_flowstart_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowstart_groups (
    id integer NOT NULL,
    flowstart_id integer NOT NULL,
    contactgroup_id integer NOT NULL
);


ALTER TABLE flows_flowstart_groups OWNER TO postgres;

--
-- Name: flows_flowstart_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowstart_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowstart_groups_id_seq OWNER TO postgres;

--
-- Name: flows_flowstart_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowstart_groups_id_seq OWNED BY flows_flowstart_groups.id;


--
-- Name: flows_flowstart_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowstart_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowstart_id_seq OWNER TO postgres;

--
-- Name: flows_flowstart_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowstart_id_seq OWNED BY flows_flowstart.id;


--
-- Name: flows_flowstep_broadcasts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowstep_broadcasts (
    id integer NOT NULL,
    flowstep_id integer NOT NULL,
    broadcast_id integer NOT NULL
);


ALTER TABLE flows_flowstep_broadcasts OWNER TO postgres;

--
-- Name: flows_flowstep_broadcasts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowstep_broadcasts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowstep_broadcasts_id_seq OWNER TO postgres;

--
-- Name: flows_flowstep_broadcasts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowstep_broadcasts_id_seq OWNED BY flows_flowstep_broadcasts.id;


--
-- Name: flows_flowstep_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowstep_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowstep_id_seq OWNER TO postgres;

--
-- Name: flows_flowstep_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowstep_id_seq OWNED BY flows_flowstep.id;


--
-- Name: flows_flowstep_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_flowstep_messages (
    id integer NOT NULL,
    flowstep_id integer NOT NULL,
    msg_id integer NOT NULL
);


ALTER TABLE flows_flowstep_messages OWNER TO postgres;

--
-- Name: flows_flowstep_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_flowstep_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_flowstep_messages_id_seq OWNER TO postgres;

--
-- Name: flows_flowstep_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_flowstep_messages_id_seq OWNED BY flows_flowstep_messages.id;


--
-- Name: flows_ruleset; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE flows_ruleset (
    id integer NOT NULL,
    uuid character varying(36) NOT NULL,
    label character varying(64),
    operand character varying(128),
    webhook_url character varying(255),
    webhook_action character varying(8),
    rules text NOT NULL,
    finished_key character varying(1),
    value_type character varying(1) NOT NULL,
    ruleset_type character varying(16),
    response_type character varying(1) NOT NULL,
    config text,
    x integer NOT NULL,
    y integer NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    flow_id integer NOT NULL
);


ALTER TABLE flows_ruleset OWNER TO postgres;

--
-- Name: flows_ruleset_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE flows_ruleset_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE flows_ruleset_id_seq OWNER TO postgres;

--
-- Name: flows_ruleset_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE flows_ruleset_id_seq OWNED BY flows_ruleset.id;


--
-- Name: guardian_groupobjectpermission; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE guardian_groupobjectpermission (
    id integer NOT NULL,
    object_pk character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE guardian_groupobjectpermission OWNER TO postgres;

--
-- Name: guardian_groupobjectpermission_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE guardian_groupobjectpermission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE guardian_groupobjectpermission_id_seq OWNER TO postgres;

--
-- Name: guardian_groupobjectpermission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE guardian_groupobjectpermission_id_seq OWNED BY guardian_groupobjectpermission.id;


--
-- Name: guardian_userobjectpermission; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE guardian_userobjectpermission (
    id integer NOT NULL,
    object_pk character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    permission_id integer NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE guardian_userobjectpermission OWNER TO postgres;

--
-- Name: guardian_userobjectpermission_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE guardian_userobjectpermission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE guardian_userobjectpermission_id_seq OWNER TO postgres;

--
-- Name: guardian_userobjectpermission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE guardian_userobjectpermission_id_seq OWNED BY guardian_userobjectpermission.id;


--
-- Name: locations_adminboundary; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE locations_adminboundary (
    id integer NOT NULL,
    osm_id character varying(15) NOT NULL,
    name character varying(128) NOT NULL,
    level integer NOT NULL,
    geometry geometry(MultiPolygon,4326),
    simplified_geometry geometry(MultiPolygon,4326),
    lft integer NOT NULL,
    rght integer NOT NULL,
    tree_id integer NOT NULL,
    parent_id integer,
    CONSTRAINT locations_adminboundary_lft_check CHECK ((lft >= 0)),
    CONSTRAINT locations_adminboundary_rght_check CHECK ((rght >= 0)),
    CONSTRAINT locations_adminboundary_tree_id_check CHECK ((tree_id >= 0))
);


ALTER TABLE locations_adminboundary OWNER TO postgres;

--
-- Name: locations_adminboundary_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE locations_adminboundary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE locations_adminboundary_id_seq OWNER TO postgres;

--
-- Name: locations_adminboundary_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE locations_adminboundary_id_seq OWNED BY locations_adminboundary.id;


--
-- Name: locations_boundaryalias; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE locations_boundaryalias (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    name character varying(128) NOT NULL,
    boundary_id integer NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE locations_boundaryalias OWNER TO postgres;

--
-- Name: locations_boundaryalias_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE locations_boundaryalias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE locations_boundaryalias_id_seq OWNER TO postgres;

--
-- Name: locations_boundaryalias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE locations_boundaryalias_id_seq OWNED BY locations_boundaryalias.id;


--
-- Name: msgs_broadcast_contacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_broadcast_contacts (
    id integer NOT NULL,
    broadcast_id integer NOT NULL,
    contact_id integer NOT NULL
);


ALTER TABLE msgs_broadcast_contacts OWNER TO postgres;

--
-- Name: msgs_broadcast_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_broadcast_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_broadcast_contacts_id_seq OWNER TO postgres;

--
-- Name: msgs_broadcast_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_broadcast_contacts_id_seq OWNED BY msgs_broadcast_contacts.id;


--
-- Name: msgs_broadcast_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_broadcast_groups (
    id integer NOT NULL,
    broadcast_id integer NOT NULL,
    contactgroup_id integer NOT NULL
);


ALTER TABLE msgs_broadcast_groups OWNER TO postgres;

--
-- Name: msgs_broadcast_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_broadcast_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_broadcast_groups_id_seq OWNER TO postgres;

--
-- Name: msgs_broadcast_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_broadcast_groups_id_seq OWNED BY msgs_broadcast_groups.id;


--
-- Name: msgs_broadcast_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_broadcast_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_broadcast_id_seq OWNER TO postgres;

--
-- Name: msgs_broadcast_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_broadcast_id_seq OWNED BY msgs_broadcast.id;


--
-- Name: msgs_broadcast_recipients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_broadcast_recipients (
    id integer NOT NULL,
    purged_status character varying(1),
    broadcast_id integer NOT NULL,
    contact_id integer NOT NULL
);


ALTER TABLE msgs_broadcast_recipients OWNER TO postgres;

--
-- Name: msgs_broadcast_recipients_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_broadcast_recipients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_broadcast_recipients_id_seq OWNER TO postgres;

--
-- Name: msgs_broadcast_recipients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_broadcast_recipients_id_seq OWNED BY msgs_broadcast_recipients.id;


--
-- Name: msgs_broadcast_urns; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_broadcast_urns (
    id integer NOT NULL,
    broadcast_id integer NOT NULL,
    contacturn_id integer NOT NULL
);


ALTER TABLE msgs_broadcast_urns OWNER TO postgres;

--
-- Name: msgs_broadcast_urns_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_broadcast_urns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_broadcast_urns_id_seq OWNER TO postgres;

--
-- Name: msgs_broadcast_urns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_broadcast_urns_id_seq OWNED BY msgs_broadcast_urns.id;


--
-- Name: msgs_exportmessagestask; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_exportmessagestask (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    start_date date,
    end_date date,
    uuid character varying(36) NOT NULL,
    created_by_id integer NOT NULL,
    label_id integer,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL,
    status character varying(1) NOT NULL,
    system_label character varying(1)
);


ALTER TABLE msgs_exportmessagestask OWNER TO postgres;

--
-- Name: msgs_exportmessagestask_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_exportmessagestask_groups (
    id integer NOT NULL,
    exportmessagestask_id integer NOT NULL,
    contactgroup_id integer NOT NULL
);


ALTER TABLE msgs_exportmessagestask_groups OWNER TO postgres;

--
-- Name: msgs_exportmessagestask_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_exportmessagestask_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_exportmessagestask_groups_id_seq OWNER TO postgres;

--
-- Name: msgs_exportmessagestask_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_exportmessagestask_groups_id_seq OWNED BY msgs_exportmessagestask_groups.id;


--
-- Name: msgs_exportmessagestask_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_exportmessagestask_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_exportmessagestask_id_seq OWNER TO postgres;

--
-- Name: msgs_exportmessagestask_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_exportmessagestask_id_seq OWNED BY msgs_exportmessagestask.id;


--
-- Name: msgs_label; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_label (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    uuid character varying(36) NOT NULL,
    name character varying(64) NOT NULL,
    label_type character varying(1) NOT NULL,
    created_by_id integer NOT NULL,
    folder_id integer,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE msgs_label OWNER TO postgres;

--
-- Name: msgs_label_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_label_id_seq OWNER TO postgres;

--
-- Name: msgs_label_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_label_id_seq OWNED BY msgs_label.id;


--
-- Name: msgs_labelcount; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_labelcount (
    id integer NOT NULL,
    is_squashed boolean NOT NULL,
    count integer NOT NULL,
    label_id integer NOT NULL
);


ALTER TABLE msgs_labelcount OWNER TO postgres;

--
-- Name: msgs_labelcount_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_labelcount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_labelcount_id_seq OWNER TO postgres;

--
-- Name: msgs_labelcount_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_labelcount_id_seq OWNED BY msgs_labelcount.id;


--
-- Name: msgs_msg_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_msg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_msg_id_seq OWNER TO postgres;

--
-- Name: msgs_msg_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_msg_id_seq OWNED BY msgs_msg.id;


--
-- Name: msgs_msg_labels; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_msg_labels (
    id integer NOT NULL,
    msg_id integer NOT NULL,
    label_id integer NOT NULL
);


ALTER TABLE msgs_msg_labels OWNER TO postgres;

--
-- Name: msgs_msg_labels_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_msg_labels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_msg_labels_id_seq OWNER TO postgres;

--
-- Name: msgs_msg_labels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_msg_labels_id_seq OWNED BY msgs_msg_labels.id;


--
-- Name: msgs_systemlabelcount; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE msgs_systemlabelcount (
    id integer NOT NULL,
    label_type character varying(1) NOT NULL,
    count integer NOT NULL,
    org_id integer NOT NULL,
    is_squashed boolean NOT NULL
);


ALTER TABLE msgs_systemlabelcount OWNER TO postgres;

--
-- Name: msgs_systemlabel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE msgs_systemlabel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE msgs_systemlabel_id_seq OWNER TO postgres;

--
-- Name: msgs_systemlabel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE msgs_systemlabel_id_seq OWNED BY msgs_systemlabelcount.id;


--
-- Name: orgs_creditalert; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_creditalert (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    alert_type character varying(1) NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE orgs_creditalert OWNER TO postgres;

--
-- Name: orgs_creditalert_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_creditalert_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_creditalert_id_seq OWNER TO postgres;

--
-- Name: orgs_creditalert_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_creditalert_id_seq OWNED BY orgs_creditalert.id;


--
-- Name: orgs_debit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_debit (
    id integer NOT NULL,
    amount integer NOT NULL,
    debit_type character varying(1) NOT NULL,
    created_on timestamp with time zone NOT NULL,
    beneficiary_id integer,
    created_by_id integer,
    topup_id integer NOT NULL,
    is_squashed boolean NOT NULL
);


ALTER TABLE orgs_debit OWNER TO postgres;

--
-- Name: orgs_debit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_debit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_debit_id_seq OWNER TO postgres;

--
-- Name: orgs_debit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_debit_id_seq OWNED BY orgs_debit.id;


--
-- Name: orgs_invitation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_invitation (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    email character varying(254) NOT NULL,
    secret character varying(64) NOT NULL,
    user_group character varying(1) NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE orgs_invitation OWNER TO postgres;

--
-- Name: orgs_invitation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_invitation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_invitation_id_seq OWNER TO postgres;

--
-- Name: orgs_invitation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_invitation_id_seq OWNED BY orgs_invitation.id;


--
-- Name: orgs_language; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_language (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    name character varying(128) NOT NULL,
    iso_code character varying(4) NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE orgs_language OWNER TO postgres;

--
-- Name: orgs_language_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_language_id_seq OWNER TO postgres;

--
-- Name: orgs_language_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_language_id_seq OWNED BY orgs_language.id;


--
-- Name: orgs_org; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_org (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    name character varying(128) NOT NULL,
    plan character varying(16) NOT NULL,
    plan_start timestamp with time zone NOT NULL,
    stripe_customer character varying(32),
    language character varying(64),
    timezone character varying(63) NOT NULL,
    date_format character varying(1) NOT NULL,
    webhook text,
    webhook_events integer NOT NULL,
    msg_last_viewed timestamp with time zone NOT NULL,
    flows_last_viewed timestamp with time zone NOT NULL,
    config text,
    slug character varying(255),
    is_anon boolean NOT NULL,
    is_purgeable boolean NOT NULL,
    brand character varying(128) NOT NULL,
    surveyor_password character varying(128),
    country_id integer,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    parent_id integer,
    primary_language_id integer
);


ALTER TABLE orgs_org OWNER TO postgres;

--
-- Name: orgs_org_administrators; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_org_administrators (
    id integer NOT NULL,
    org_id integer NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE orgs_org_administrators OWNER TO postgres;

--
-- Name: orgs_org_administrators_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_org_administrators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_org_administrators_id_seq OWNER TO postgres;

--
-- Name: orgs_org_administrators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_org_administrators_id_seq OWNED BY orgs_org_administrators.id;


--
-- Name: orgs_org_editors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_org_editors (
    id integer NOT NULL,
    org_id integer NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE orgs_org_editors OWNER TO postgres;

--
-- Name: orgs_org_editors_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_org_editors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_org_editors_id_seq OWNER TO postgres;

--
-- Name: orgs_org_editors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_org_editors_id_seq OWNED BY orgs_org_editors.id;


--
-- Name: orgs_org_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_org_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_org_id_seq OWNER TO postgres;

--
-- Name: orgs_org_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_org_id_seq OWNED BY orgs_org.id;


--
-- Name: orgs_org_surveyors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_org_surveyors (
    id integer NOT NULL,
    org_id integer NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE orgs_org_surveyors OWNER TO postgres;

--
-- Name: orgs_org_surveyors_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_org_surveyors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_org_surveyors_id_seq OWNER TO postgres;

--
-- Name: orgs_org_surveyors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_org_surveyors_id_seq OWNED BY orgs_org_surveyors.id;


--
-- Name: orgs_org_viewers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_org_viewers (
    id integer NOT NULL,
    org_id integer NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE orgs_org_viewers OWNER TO postgres;

--
-- Name: orgs_org_viewers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_org_viewers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_org_viewers_id_seq OWNER TO postgres;

--
-- Name: orgs_org_viewers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_org_viewers_id_seq OWNED BY orgs_org_viewers.id;


--
-- Name: orgs_topup; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_topup (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    price integer,
    credits integer NOT NULL,
    expires_on timestamp with time zone NOT NULL,
    stripe_charge character varying(32),
    comment character varying(255),
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE orgs_topup OWNER TO postgres;

--
-- Name: orgs_topup_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_topup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_topup_id_seq OWNER TO postgres;

--
-- Name: orgs_topup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_topup_id_seq OWNED BY orgs_topup.id;


--
-- Name: orgs_topupcredits; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_topupcredits (
    id integer NOT NULL,
    used integer NOT NULL,
    topup_id integer NOT NULL,
    is_squashed boolean NOT NULL
);


ALTER TABLE orgs_topupcredits OWNER TO postgres;

--
-- Name: orgs_topupcredits_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_topupcredits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_topupcredits_id_seq OWNER TO postgres;

--
-- Name: orgs_topupcredits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_topupcredits_id_seq OWNED BY orgs_topupcredits.id;


--
-- Name: orgs_usersettings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orgs_usersettings (
    id integer NOT NULL,
    language character varying(8) NOT NULL,
    tel character varying(16),
    user_id integer NOT NULL
);


ALTER TABLE orgs_usersettings OWNER TO postgres;

--
-- Name: orgs_usersettings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_usersettings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_usersettings_id_seq OWNER TO postgres;

--
-- Name: orgs_usersettings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_usersettings_id_seq OWNED BY orgs_usersettings.id;


--
-- Name: public_lead; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public_lead (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    email character varying(254) NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL
);


ALTER TABLE public_lead OWNER TO postgres;

--
-- Name: public_lead_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public_lead_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public_lead_id_seq OWNER TO postgres;

--
-- Name: public_lead_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public_lead_id_seq OWNED BY public_lead.id;


--
-- Name: public_video; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public_video (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    name character varying(255) NOT NULL,
    summary text NOT NULL,
    description text NOT NULL,
    vimeo_id character varying(255) NOT NULL,
    "order" integer NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL
);


ALTER TABLE public_video OWNER TO postgres;

--
-- Name: public_video_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public_video_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public_video_id_seq OWNER TO postgres;

--
-- Name: public_video_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public_video_id_seq OWNED BY public_video.id;


--
-- Name: reports_report; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE reports_report (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    title character varying(64) NOT NULL,
    description text NOT NULL,
    config text,
    is_published boolean NOT NULL,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL
);


ALTER TABLE reports_report OWNER TO postgres;

--
-- Name: reports_report_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE reports_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE reports_report_id_seq OWNER TO postgres;

--
-- Name: reports_report_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE reports_report_id_seq OWNED BY reports_report.id;


--
-- Name: schedules_schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE schedules_schedule (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    status character varying(1) NOT NULL,
    repeat_hour_of_day integer,
    repeat_minute_of_hour integer,
    repeat_day_of_month integer,
    repeat_period character varying(1),
    repeat_days integer,
    last_fire timestamp with time zone,
    next_fire timestamp with time zone,
    created_by_id integer NOT NULL,
    modified_by_id integer NOT NULL
);


ALTER TABLE schedules_schedule OWNER TO postgres;

--
-- Name: schedules_schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE schedules_schedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE schedules_schedule_id_seq OWNER TO postgres;

--
-- Name: schedules_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE schedules_schedule_id_seq OWNED BY schedules_schedule.id;


--
-- Name: triggers_trigger; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE triggers_trigger (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    keyword character varying(16),
    last_triggered timestamp with time zone,
    trigger_count integer NOT NULL,
    is_archived boolean NOT NULL,
    trigger_type character varying(1) NOT NULL,
    channel_id integer,
    created_by_id integer NOT NULL,
    flow_id integer NOT NULL,
    modified_by_id integer NOT NULL,
    org_id integer NOT NULL,
    schedule_id integer,
    referrer_id character varying(255),
    match_type character varying(1)
);


ALTER TABLE triggers_trigger OWNER TO postgres;

--
-- Name: triggers_trigger_contacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE triggers_trigger_contacts (
    id integer NOT NULL,
    trigger_id integer NOT NULL,
    contact_id integer NOT NULL
);


ALTER TABLE triggers_trigger_contacts OWNER TO postgres;

--
-- Name: triggers_trigger_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE triggers_trigger_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE triggers_trigger_contacts_id_seq OWNER TO postgres;

--
-- Name: triggers_trigger_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE triggers_trigger_contacts_id_seq OWNED BY triggers_trigger_contacts.id;


--
-- Name: triggers_trigger_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE triggers_trigger_groups (
    id integer NOT NULL,
    trigger_id integer NOT NULL,
    contactgroup_id integer NOT NULL
);


ALTER TABLE triggers_trigger_groups OWNER TO postgres;

--
-- Name: triggers_trigger_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE triggers_trigger_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE triggers_trigger_groups_id_seq OWNER TO postgres;

--
-- Name: triggers_trigger_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE triggers_trigger_groups_id_seq OWNED BY triggers_trigger_groups.id;


--
-- Name: triggers_trigger_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE triggers_trigger_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE triggers_trigger_id_seq OWNER TO postgres;

--
-- Name: triggers_trigger_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE triggers_trigger_id_seq OWNED BY triggers_trigger.id;


--
-- Name: users_failedlogin; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE users_failedlogin (
    id integer NOT NULL,
    failed_on timestamp with time zone NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE users_failedlogin OWNER TO postgres;

--
-- Name: users_failedlogin_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE users_failedlogin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_failedlogin_id_seq OWNER TO postgres;

--
-- Name: users_failedlogin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE users_failedlogin_id_seq OWNED BY users_failedlogin.id;


--
-- Name: users_passwordhistory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE users_passwordhistory (
    id integer NOT NULL,
    password character varying(255) NOT NULL,
    set_on timestamp with time zone NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE users_passwordhistory OWNER TO postgres;

--
-- Name: users_passwordhistory_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE users_passwordhistory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_passwordhistory_id_seq OWNER TO postgres;

--
-- Name: users_passwordhistory_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE users_passwordhistory_id_seq OWNED BY users_passwordhistory.id;


--
-- Name: users_recoverytoken; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE users_recoverytoken (
    id integer NOT NULL,
    token character varying(32) NOT NULL,
    created_on timestamp with time zone NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE users_recoverytoken OWNER TO postgres;

--
-- Name: users_recoverytoken_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE users_recoverytoken_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_recoverytoken_id_seq OWNER TO postgres;

--
-- Name: users_recoverytoken_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE users_recoverytoken_id_seq OWNED BY users_recoverytoken.id;


--
-- Name: values_value; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE values_value (
    id integer NOT NULL,
    rule_uuid character varying(255),
    category character varying(128),
    string_value text NOT NULL,
    decimal_value numeric(36,8),
    datetime_value timestamp with time zone,
    media_value text,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    contact_id integer NOT NULL,
    contact_field_id integer,
    location_value_id integer,
    org_id integer NOT NULL,
    ruleset_id integer,
    run_id integer
);


ALTER TABLE values_value OWNER TO postgres;

--
-- Name: values_value_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE values_value_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE values_value_id_seq OWNER TO postgres;

--
-- Name: values_value_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE values_value_id_seq OWNED BY values_value.id;


--
-- Name: airtime_airtimetransfer id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY airtime_airtimetransfer ALTER COLUMN id SET DEFAULT nextval('airtime_airtimetransfer_id_seq'::regclass);


--
-- Name: api_resthook id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_resthook ALTER COLUMN id SET DEFAULT nextval('api_resthook_id_seq'::regclass);


--
-- Name: api_resthooksubscriber id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_resthooksubscriber ALTER COLUMN id SET DEFAULT nextval('api_resthooksubscriber_id_seq'::regclass);


--
-- Name: api_webhookevent id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookevent ALTER COLUMN id SET DEFAULT nextval('api_webhookevent_id_seq'::regclass);


--
-- Name: api_webhookresult id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookresult ALTER COLUMN id SET DEFAULT nextval('api_webhookresult_id_seq'::regclass);


--
-- Name: auth_group id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group ALTER COLUMN id SET DEFAULT nextval('auth_group_id_seq'::regclass);


--
-- Name: auth_group_permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group_permissions ALTER COLUMN id SET DEFAULT nextval('auth_group_permissions_id_seq'::regclass);


--
-- Name: auth_permission id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_permission ALTER COLUMN id SET DEFAULT nextval('auth_permission_id_seq'::regclass);


--
-- Name: auth_user id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user ALTER COLUMN id SET DEFAULT nextval('auth_user_id_seq'::regclass);


--
-- Name: auth_user_groups id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_groups ALTER COLUMN id SET DEFAULT nextval('auth_user_groups_id_seq'::regclass);


--
-- Name: auth_user_user_permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_user_permissions ALTER COLUMN id SET DEFAULT nextval('auth_user_user_permissions_id_seq'::regclass);


--
-- Name: campaigns_campaign id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaign ALTER COLUMN id SET DEFAULT nextval('campaigns_campaign_id_seq'::regclass);


--
-- Name: campaigns_campaignevent id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaignevent ALTER COLUMN id SET DEFAULT nextval('campaigns_campaignevent_id_seq'::regclass);


--
-- Name: campaigns_eventfire id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_eventfire ALTER COLUMN id SET DEFAULT nextval('campaigns_eventfire_id_seq'::regclass);


--
-- Name: channels_alert id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_alert ALTER COLUMN id SET DEFAULT nextval('channels_alert_id_seq'::regclass);


--
-- Name: channels_channel id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channel ALTER COLUMN id SET DEFAULT nextval('channels_channel_id_seq'::regclass);


--
-- Name: channels_channelcount id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelcount ALTER COLUMN id SET DEFAULT nextval('channels_channelcount_id_seq'::regclass);


--
-- Name: channels_channelevent id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelevent ALTER COLUMN id SET DEFAULT nextval('channels_channelevent_id_seq'::regclass);


--
-- Name: channels_channellog id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channellog ALTER COLUMN id SET DEFAULT nextval('channels_channellog_id_seq'::regclass);


--
-- Name: channels_channelsession id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelsession ALTER COLUMN id SET DEFAULT nextval('channels_channelsession_id_seq'::regclass);


--
-- Name: channels_syncevent id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_syncevent ALTER COLUMN id SET DEFAULT nextval('channels_syncevent_id_seq'::regclass);


--
-- Name: contacts_contact id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contact ALTER COLUMN id SET DEFAULT nextval('contacts_contact_id_seq'::regclass);


--
-- Name: contacts_contactfield id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactfield ALTER COLUMN id SET DEFAULT nextval('contacts_contactfield_id_seq'::regclass);


--
-- Name: contacts_contactgroup id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup ALTER COLUMN id SET DEFAULT nextval('contacts_contactgroup_id_seq'::regclass);


--
-- Name: contacts_contactgroup_contacts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup_contacts ALTER COLUMN id SET DEFAULT nextval('contacts_contactgroup_contacts_id_seq'::regclass);


--
-- Name: contacts_contactgroup_query_fields id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup_query_fields ALTER COLUMN id SET DEFAULT nextval('contacts_contactgroup_query_fields_id_seq'::regclass);


--
-- Name: contacts_contactgroupcount id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroupcount ALTER COLUMN id SET DEFAULT nextval('contacts_contactgroupcount_id_seq'::regclass);


--
-- Name: contacts_contacturn id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contacturn ALTER COLUMN id SET DEFAULT nextval('contacts_contacturn_id_seq'::regclass);


--
-- Name: contacts_exportcontactstask id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_exportcontactstask ALTER COLUMN id SET DEFAULT nextval('contacts_exportcontactstask_id_seq'::regclass);


--
-- Name: csv_imports_importtask id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY csv_imports_importtask ALTER COLUMN id SET DEFAULT nextval('csv_imports_importtask_id_seq'::regclass);


--
-- Name: django_content_type id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_content_type ALTER COLUMN id SET DEFAULT nextval('django_content_type_id_seq'::regclass);


--
-- Name: django_migrations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_migrations ALTER COLUMN id SET DEFAULT nextval('django_migrations_id_seq'::regclass);


--
-- Name: django_site id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_site ALTER COLUMN id SET DEFAULT nextval('django_site_id_seq'::regclass);


--
-- Name: flows_actionlog id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_actionlog ALTER COLUMN id SET DEFAULT nextval('flows_actionlog_id_seq'::regclass);


--
-- Name: flows_actionset id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_actionset ALTER COLUMN id SET DEFAULT nextval('flows_actionset_id_seq'::regclass);


--
-- Name: flows_exportflowresultstask id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_exportflowresultstask ALTER COLUMN id SET DEFAULT nextval('flows_exportflowresultstask_id_seq'::regclass);


--
-- Name: flows_exportflowresultstask_flows id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_exportflowresultstask_flows ALTER COLUMN id SET DEFAULT nextval('flows_exportflowresultstask_flows_id_seq'::regclass);


--
-- Name: flows_flow id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow ALTER COLUMN id SET DEFAULT nextval('flows_flow_id_seq'::regclass);


--
-- Name: flows_flow_labels id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow_labels ALTER COLUMN id SET DEFAULT nextval('flows_flow_labels_id_seq'::regclass);


--
-- Name: flows_flowlabel id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowlabel ALTER COLUMN id SET DEFAULT nextval('flows_flowlabel_id_seq'::regclass);


--
-- Name: flows_flownodecount id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flownodecount ALTER COLUMN id SET DEFAULT nextval('flows_flownodecount_id_seq'::regclass);


--
-- Name: flows_flowpathcount id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowpathcount ALTER COLUMN id SET DEFAULT nextval('flows_flowpathcount_id_seq'::regclass);


--
-- Name: flows_flowpathrecentstep id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowpathrecentstep ALTER COLUMN id SET DEFAULT nextval('flows_flowpathrecentstep_id_seq'::regclass);


--
-- Name: flows_flowrevision id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrevision ALTER COLUMN id SET DEFAULT nextval('flows_flowrevision_id_seq'::regclass);


--
-- Name: flows_flowrun id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrun ALTER COLUMN id SET DEFAULT nextval('flows_flowrun_id_seq'::regclass);


--
-- Name: flows_flowruncount id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowruncount ALTER COLUMN id SET DEFAULT nextval('flows_flowruncount_id_seq'::regclass);


--
-- Name: flows_flowstart id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart ALTER COLUMN id SET DEFAULT nextval('flows_flowstart_id_seq'::regclass);


--
-- Name: flows_flowstart_contacts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart_contacts ALTER COLUMN id SET DEFAULT nextval('flows_flowstart_contacts_id_seq'::regclass);


--
-- Name: flows_flowstart_groups id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart_groups ALTER COLUMN id SET DEFAULT nextval('flows_flowstart_groups_id_seq'::regclass);


--
-- Name: flows_flowstep id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep ALTER COLUMN id SET DEFAULT nextval('flows_flowstep_id_seq'::regclass);


--
-- Name: flows_flowstep_broadcasts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep_broadcasts ALTER COLUMN id SET DEFAULT nextval('flows_flowstep_broadcasts_id_seq'::regclass);


--
-- Name: flows_flowstep_messages id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep_messages ALTER COLUMN id SET DEFAULT nextval('flows_flowstep_messages_id_seq'::regclass);


--
-- Name: flows_ruleset id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_ruleset ALTER COLUMN id SET DEFAULT nextval('flows_ruleset_id_seq'::regclass);


--
-- Name: guardian_groupobjectpermission id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_groupobjectpermission ALTER COLUMN id SET DEFAULT nextval('guardian_groupobjectpermission_id_seq'::regclass);


--
-- Name: guardian_userobjectpermission id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_userobjectpermission ALTER COLUMN id SET DEFAULT nextval('guardian_userobjectpermission_id_seq'::regclass);


--
-- Name: locations_adminboundary id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations_adminboundary ALTER COLUMN id SET DEFAULT nextval('locations_adminboundary_id_seq'::regclass);


--
-- Name: locations_boundaryalias id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations_boundaryalias ALTER COLUMN id SET DEFAULT nextval('locations_boundaryalias_id_seq'::regclass);


--
-- Name: msgs_broadcast id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast ALTER COLUMN id SET DEFAULT nextval('msgs_broadcast_id_seq'::regclass);


--
-- Name: msgs_broadcast_contacts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_contacts ALTER COLUMN id SET DEFAULT nextval('msgs_broadcast_contacts_id_seq'::regclass);


--
-- Name: msgs_broadcast_groups id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_groups ALTER COLUMN id SET DEFAULT nextval('msgs_broadcast_groups_id_seq'::regclass);


--
-- Name: msgs_broadcast_recipients id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_recipients ALTER COLUMN id SET DEFAULT nextval('msgs_broadcast_recipients_id_seq'::regclass);


--
-- Name: msgs_broadcast_urns id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_urns ALTER COLUMN id SET DEFAULT nextval('msgs_broadcast_urns_id_seq'::regclass);


--
-- Name: msgs_exportmessagestask id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask ALTER COLUMN id SET DEFAULT nextval('msgs_exportmessagestask_id_seq'::regclass);


--
-- Name: msgs_exportmessagestask_groups id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask_groups ALTER COLUMN id SET DEFAULT nextval('msgs_exportmessagestask_groups_id_seq'::regclass);


--
-- Name: msgs_label id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_label ALTER COLUMN id SET DEFAULT nextval('msgs_label_id_seq'::regclass);


--
-- Name: msgs_labelcount id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_labelcount ALTER COLUMN id SET DEFAULT nextval('msgs_labelcount_id_seq'::regclass);


--
-- Name: msgs_msg id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg ALTER COLUMN id SET DEFAULT nextval('msgs_msg_id_seq'::regclass);


--
-- Name: msgs_msg_labels id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg_labels ALTER COLUMN id SET DEFAULT nextval('msgs_msg_labels_id_seq'::regclass);


--
-- Name: msgs_systemlabelcount id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_systemlabelcount ALTER COLUMN id SET DEFAULT nextval('msgs_systemlabel_id_seq'::regclass);


--
-- Name: orgs_creditalert id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_creditalert ALTER COLUMN id SET DEFAULT nextval('orgs_creditalert_id_seq'::regclass);


--
-- Name: orgs_debit id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_debit ALTER COLUMN id SET DEFAULT nextval('orgs_debit_id_seq'::regclass);


--
-- Name: orgs_invitation id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_invitation ALTER COLUMN id SET DEFAULT nextval('orgs_invitation_id_seq'::regclass);


--
-- Name: orgs_language id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_language ALTER COLUMN id SET DEFAULT nextval('orgs_language_id_seq'::regclass);


--
-- Name: orgs_org id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org ALTER COLUMN id SET DEFAULT nextval('orgs_org_id_seq'::regclass);


--
-- Name: orgs_org_administrators id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_administrators ALTER COLUMN id SET DEFAULT nextval('orgs_org_administrators_id_seq'::regclass);


--
-- Name: orgs_org_editors id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_editors ALTER COLUMN id SET DEFAULT nextval('orgs_org_editors_id_seq'::regclass);


--
-- Name: orgs_org_surveyors id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_surveyors ALTER COLUMN id SET DEFAULT nextval('orgs_org_surveyors_id_seq'::regclass);


--
-- Name: orgs_org_viewers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_viewers ALTER COLUMN id SET DEFAULT nextval('orgs_org_viewers_id_seq'::regclass);


--
-- Name: orgs_topup id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_topup ALTER COLUMN id SET DEFAULT nextval('orgs_topup_id_seq'::regclass);


--
-- Name: orgs_topupcredits id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_topupcredits ALTER COLUMN id SET DEFAULT nextval('orgs_topupcredits_id_seq'::regclass);


--
-- Name: orgs_usersettings id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_usersettings ALTER COLUMN id SET DEFAULT nextval('orgs_usersettings_id_seq'::regclass);


--
-- Name: public_lead id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public_lead ALTER COLUMN id SET DEFAULT nextval('public_lead_id_seq'::regclass);


--
-- Name: public_video id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public_video ALTER COLUMN id SET DEFAULT nextval('public_video_id_seq'::regclass);


--
-- Name: reports_report id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reports_report ALTER COLUMN id SET DEFAULT nextval('reports_report_id_seq'::regclass);


--
-- Name: schedules_schedule id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY schedules_schedule ALTER COLUMN id SET DEFAULT nextval('schedules_schedule_id_seq'::regclass);


--
-- Name: triggers_trigger id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger ALTER COLUMN id SET DEFAULT nextval('triggers_trigger_id_seq'::regclass);


--
-- Name: triggers_trigger_contacts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger_contacts ALTER COLUMN id SET DEFAULT nextval('triggers_trigger_contacts_id_seq'::regclass);


--
-- Name: triggers_trigger_groups id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger_groups ALTER COLUMN id SET DEFAULT nextval('triggers_trigger_groups_id_seq'::regclass);


--
-- Name: users_failedlogin id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users_failedlogin ALTER COLUMN id SET DEFAULT nextval('users_failedlogin_id_seq'::regclass);


--
-- Name: users_passwordhistory id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users_passwordhistory ALTER COLUMN id SET DEFAULT nextval('users_passwordhistory_id_seq'::regclass);


--
-- Name: users_recoverytoken id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users_recoverytoken ALTER COLUMN id SET DEFAULT nextval('users_recoverytoken_id_seq'::regclass);


--
-- Name: values_value id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY values_value ALTER COLUMN id SET DEFAULT nextval('values_value_id_seq'::regclass);


--
-- Data for Name: airtime_airtimetransfer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY airtime_airtimetransfer (id, is_active, created_on, modified_on, status, recipient, amount, denomination, data, response, message, channel_id, contact_id, created_by_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: airtime_airtimetransfer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('airtime_airtimetransfer_id_seq', 1, false);


--
-- Data for Name: api_apitoken; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY api_apitoken (is_active, key, created, org_id, role_id, user_id) FROM stdin;
\.


--
-- Data for Name: api_resthook; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY api_resthook (id, is_active, created_on, modified_on, slug, created_by_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: api_resthook_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('api_resthook_id_seq', 1, false);


--
-- Data for Name: api_resthooksubscriber; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY api_resthooksubscriber (id, is_active, created_on, modified_on, target_url, created_by_id, modified_by_id, resthook_id) FROM stdin;
\.


--
-- Name: api_resthooksubscriber_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('api_resthooksubscriber_id_seq', 1, false);


--
-- Data for Name: api_webhookevent; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY api_webhookevent (id, is_active, created_on, modified_on, status, event, data, try_count, next_attempt, action, channel_id, created_by_id, modified_by_id, org_id, resthook_id, run_id) FROM stdin;
\.


--
-- Name: api_webhookevent_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('api_webhookevent_id_seq', 1, false);


--
-- Data for Name: api_webhookresult; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY api_webhookresult (id, is_active, created_on, modified_on, url, data, request, status_code, message, body, created_by_id, event_id, modified_by_id, request_time) FROM stdin;
\.


--
-- Name: api_webhookresult_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('api_webhookresult_id_seq', 1, false);


--
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_group (id, name) FROM stdin;
1	Administrators
2	Surveyors
3	Beta
4	Customer Support
5	Service Users
6	Alpha
7	Granters
8	Editors
9	Viewers
\.


--
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_group_id_seq', 9, true);


--
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_group_permissions (id, group_id, permission_id) FROM stdin;
1	1	607
2	1	604
3	1	223
4	1	233
5	1	234
6	1	228
7	1	734
8	1	318
9	1	315
10	1	224
11	1	225
12	1	568
13	1	571
14	1	572
15	1	569
16	1	570
17	1	711
18	1	563
19	1	566
20	1	567
21	1	564
22	1	565
23	1	611
24	1	612
25	1	613
26	1	398
27	1	615
28	1	401
29	1	616
30	1	618
31	1	619
32	1	620
33	1	402
34	1	621
35	1	399
36	1	617
37	1	622
38	1	623
39	1	400
40	1	624
41	1	625
42	1	608
43	1	383
44	1	386
45	1	609
46	1	387
47	1	610
48	1	384
49	1	385
50	1	770
51	1	388
52	1	391
53	1	392
54	1	389
55	1	390
56	1	284
57	1	287
58	1	288
59	1	285
60	1	286
61	1	578
62	1	581
63	1	582
64	1	579
65	1	675
66	1	580
67	1	583
68	1	586
69	1	587
70	1	584
71	1	585
72	1	235
73	1	236
74	1	237
75	1	238
76	1	735
77	1	736
78	1	737
79	1	738
80	1	741
81	1	742
82	1	743
83	1	744
84	1	745
85	1	747
86	1	748
87	1	750
88	1	752
89	1	753
90	1	755
91	1	756
92	1	754
93	1	757
94	1	758
95	1	759
96	1	762
97	1	764
98	1	765
99	1	767
100	1	768
101	1	769
102	1	367
103	1	364
104	1	690
105	1	360
106	1	649
107	1	626
108	1	627
109	1	628
110	1	629
111	1	630
112	1	631
113	1	632
114	1	633
115	1	634
116	1	635
117	1	636
118	1	637
119	1	638
120	1	639
121	1	640
122	1	641
123	1	642
124	1	643
125	1	644
126	1	645
127	1	646
128	1	648
129	1	647
130	1	650
131	1	651
132	1	652
133	1	653
134	1	654
135	1	655
136	1	656
137	1	657
138	1	658
139	1	659
140	1	660
141	1	661
142	1	662
143	1	663
144	1	664
145	1	665
146	1	666
147	1	667
148	1	668
149	1	413
150	1	669
151	1	670
152	1	672
153	1	416
154	1	417
155	1	414
156	1	673
157	1	674
158	1	415
159	1	676
160	1	677
161	1	418
162	1	421
163	1	422
164	1	419
165	1	420
166	1	437
167	1	434
168	1	227
169	1	553
170	1	556
171	1	557
172	1	554
173	1	555
174	1	712
175	1	713
176	1	714
177	1	715
178	1	716
179	1	717
180	1	718
181	1	719
182	1	720
183	1	721
184	1	543
185	1	546
186	1	722
187	1	723
188	1	724
189	1	725
190	1	726
191	1	547
192	1	544
193	1	727
194	1	728
195	1	729
196	1	730
197	1	731
198	1	545
199	1	732
200	1	733
201	1	678
202	1	493
203	1	496
204	1	497
205	1	494
206	1	495
207	1	229
208	1	230
209	1	508
210	1	511
211	1	512
212	1	231
213	1	509
214	1	232
215	1	510
216	1	491
217	1	338
218	1	341
219	1	342
220	1	339
221	1	340
222	1	705
223	1	448
224	1	451
225	1	706
226	1	452
227	1	449
228	1	707
229	1	708
230	1	709
231	1	710
232	1	450
233	1	691
234	1	473
235	1	692
236	1	476
237	1	477
238	1	474
239	1	475
240	1	693
241	1	694
242	1	695
243	1	471
244	1	696
245	1	697
246	1	698
247	1	699
248	1	700
249	1	701
250	1	702
251	1	703
252	1	470
253	1	679
254	1	680
255	1	558
256	1	561
257	1	681
258	1	682
259	1	683
260	1	562
261	1	684
262	1	685
263	1	559
264	1	686
265	1	687
266	1	688
267	1	560
268	1	689
269	2	611
270	2	608
271	2	716
272	2	236
273	2	737
274	2	763
275	2	693
276	4	248
277	4	246
278	4	614
279	4	722
280	4	726
281	4	544
282	4	729
283	4	491
284	4	746
285	4	751
286	4	350
287	4	760
288	4	363
289	4	226
290	4	365
291	5	468
292	7	746
293	8	223
294	8	233
295	8	234
296	8	228
297	8	734
298	8	318
299	8	315
300	8	607
301	8	604
302	8	224
303	8	225
304	8	568
305	8	571
306	8	572
307	8	569
308	8	570
309	8	711
310	8	563
311	8	566
312	8	567
313	8	564
314	8	565
315	8	611
316	8	612
317	8	613
318	8	398
319	8	615
320	8	401
321	8	616
322	8	618
323	8	619
324	8	620
325	8	402
326	8	621
327	8	399
328	8	617
329	8	622
330	8	623
331	8	400
332	8	624
333	8	625
334	8	608
335	8	383
336	8	386
337	8	609
338	8	387
339	8	610
340	8	384
341	8	385
342	8	770
343	8	388
344	8	391
345	8	392
346	8	389
347	8	390
348	8	284
349	8	287
350	8	288
351	8	285
352	8	286
353	8	578
354	8	581
355	8	582
356	8	579
357	8	675
358	8	580
359	8	583
360	8	586
361	8	587
362	8	584
363	8	585
364	8	235
365	8	236
366	8	237
367	8	238
368	8	737
369	8	742
370	8	745
371	8	747
372	8	748
373	8	758
374	8	759
375	8	769
376	8	367
377	8	364
378	8	690
379	8	360
380	8	626
381	8	627
382	8	628
383	8	629
384	8	630
385	8	631
386	8	632
387	8	633
388	8	634
389	8	635
390	8	636
391	8	637
392	8	638
393	8	639
394	8	640
395	8	641
396	8	642
397	8	643
398	8	644
399	8	645
400	8	648
401	8	646
402	8	647
403	8	650
404	8	651
405	8	652
406	8	653
407	8	654
408	8	655
409	8	656
410	8	657
411	8	658
412	8	659
413	8	660
414	8	661
415	8	662
416	8	663
417	8	664
418	8	665
419	8	666
420	8	667
421	8	668
422	8	413
423	8	669
424	8	670
425	8	416
426	8	417
427	8	414
428	8	674
429	8	415
430	8	676
431	8	677
432	8	418
433	8	421
434	8	422
435	8	419
436	8	420
437	8	553
438	8	556
439	8	557
440	8	554
441	8	555
442	8	712
443	8	713
444	8	714
445	8	715
446	8	716
447	8	717
448	8	718
449	8	719
450	8	720
451	8	721
452	8	543
453	8	546
454	8	722
455	8	723
456	8	724
457	8	725
458	8	726
459	8	547
460	8	544
461	8	727
462	8	728
463	8	729
464	8	730
465	8	731
466	8	545
467	8	732
468	8	733
469	8	678
470	8	493
471	8	496
472	8	497
473	8	494
474	8	495
475	8	229
476	8	230
477	8	508
478	8	511
479	8	512
480	8	231
481	8	509
482	8	232
483	8	510
484	8	338
485	8	341
486	8	342
487	8	339
488	8	340
489	8	705
490	8	448
491	8	451
492	8	706
493	8	452
494	8	449
495	8	707
496	8	708
497	8	709
498	8	710
499	8	450
500	8	691
501	8	473
502	8	692
503	8	476
504	8	477
505	8	474
506	8	475
507	8	693
508	8	694
509	8	695
510	8	471
511	8	696
512	8	697
513	8	698
514	8	699
515	8	700
516	8	701
517	8	702
518	8	703
519	8	470
520	8	679
521	8	680
522	8	558
523	8	561
524	8	681
525	8	682
526	8	683
527	8	562
528	8	684
529	8	685
530	8	559
531	8	686
532	8	687
533	8	688
534	8	560
535	8	689
536	9	234
537	9	225
538	9	572
539	9	569
540	9	564
541	9	613
542	9	616
543	9	618
544	9	619
545	9	402
546	9	399
547	9	617
548	9	237
549	9	238
550	9	235
551	9	742
552	9	745
553	9	747
554	9	758
555	9	367
556	9	364
557	9	417
558	9	414
559	9	677
560	9	712
561	9	713
562	9	717
563	9	719
564	9	720
565	9	723
566	9	724
567	9	725
568	9	547
569	9	544
570	9	722
571	9	726
572	9	727
573	9	728
574	9	730
575	9	731
576	9	229
577	9	232
578	9	230
579	9	708
580	9	709
581	9	695
582	9	696
583	9	697
584	9	698
585	9	699
586	9	700
587	9	702
588	9	703
589	9	679
590	9	562
\.


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_group_permissions_id_seq', 590, true);


--
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_permission (id, name, content_type_id, codename) FROM stdin;
1	Can add group	1	add_group
2	Can change group	1	change_group
3	Can delete group	1	delete_group
4	Can add user	2	add_user
5	Can change user	2	change_user
6	Can delete user	2	delete_user
7	Can add permission	3	add_permission
8	Can change permission	3	change_permission
9	Can delete permission	3	delete_permission
10	Can add content type	4	add_contenttype
11	Can change content type	4	change_contenttype
12	Can delete content type	4	delete_contenttype
13	Can add session	5	add_session
14	Can change session	5	change_session
15	Can delete session	5	delete_session
16	Can add site	6	add_site
17	Can change site	6	change_site
18	Can delete site	6	delete_site
19	Can add group object permission	7	add_groupobjectpermission
20	Can change group object permission	7	change_groupobjectpermission
21	Can delete group object permission	7	delete_groupobjectpermission
22	Can add user object permission	8	add_userobjectpermission
23	Can change user object permission	8	change_userobjectpermission
24	Can delete user object permission	8	delete_userobjectpermission
25	Can add Token	9	add_token
26	Can change Token	9	change_token
27	Can delete Token	9	delete_token
28	Can add import task	10	add_importtask
29	Can change import task	10	change_importtask
30	Can delete import task	10	delete_importtask
31	Can add recovery token	11	add_recoverytoken
32	Can change recovery token	11	change_recoverytoken
33	Can delete recovery token	11	delete_recoverytoken
34	Can add failed login	12	add_failedlogin
35	Can change failed login	12	change_failedlogin
36	Can delete failed login	12	delete_failedlogin
37	Can add password history	13	add_passwordhistory
38	Can change password history	13	change_passwordhistory
39	Can delete password history	13	delete_passwordhistory
40	Can add api token	14	add_apitoken
41	Can change api token	14	change_apitoken
42	Can delete api token	14	delete_apitoken
43	Can add web hook result	15	add_webhookresult
44	Can change web hook result	15	change_webhookresult
45	Can delete web hook result	15	delete_webhookresult
46	Can add web hook event	16	add_webhookevent
47	Can change web hook event	16	change_webhookevent
48	Can delete web hook event	16	delete_webhookevent
49	Can add resthook subscriber	17	add_resthooksubscriber
50	Can change resthook subscriber	17	change_resthooksubscriber
51	Can delete resthook subscriber	17	delete_resthooksubscriber
52	Can add resthook	18	add_resthook
53	Can change resthook	18	change_resthook
54	Can delete resthook	18	delete_resthook
55	Can add video	19	add_video
56	Can change video	19	change_video
57	Can delete video	19	delete_video
58	Can add lead	20	add_lead
59	Can change lead	20	change_lead
60	Can delete lead	20	delete_lead
61	Can add schedule	21	add_schedule
62	Can change schedule	21	change_schedule
63	Can delete schedule	21	delete_schedule
64	Can add invitation	22	add_invitation
65	Can change invitation	22	change_invitation
66	Can delete invitation	22	delete_invitation
67	Can add org	23	add_org
68	Can change org	23	change_org
69	Can delete org	23	delete_org
70	Can add top up credits	24	add_topupcredits
71	Can change top up credits	24	change_topupcredits
72	Can delete top up credits	24	delete_topupcredits
73	Can add user settings	25	add_usersettings
74	Can change user settings	25	change_usersettings
75	Can delete user settings	25	delete_usersettings
76	Can add top up	26	add_topup
77	Can change top up	26	change_topup
78	Can delete top up	26	delete_topup
79	Can add language	27	add_language
80	Can change language	27	change_language
81	Can delete language	27	delete_language
82	Can add credit alert	28	add_creditalert
83	Can change credit alert	28	change_creditalert
84	Can delete credit alert	28	delete_creditalert
85	Can add debit	29	add_debit
86	Can change debit	29	change_debit
87	Can delete debit	29	delete_debit
88	Can add contact field	30	add_contactfield
89	Can change contact field	30	change_contactfield
90	Can delete contact field	30	delete_contactfield
91	Can add contact group	31	add_contactgroup
92	Can change contact group	31	change_contactgroup
93	Can delete contact group	31	delete_contactgroup
94	Can add export contacts task	32	add_exportcontactstask
95	Can change export contacts task	32	change_exportcontactstask
96	Can delete export contacts task	32	delete_exportcontactstask
97	Can add contact	33	add_contact
98	Can change contact	33	change_contact
99	Can delete contact	33	delete_contact
100	Can add contact urn	34	add_contacturn
101	Can change contact urn	34	change_contacturn
102	Can delete contact urn	34	delete_contacturn
103	Can add contact group count	35	add_contactgroupcount
104	Can change contact group count	35	change_contactgroupcount
105	Can delete contact group count	35	delete_contactgroupcount
106	Can add channel	36	add_channel
107	Can change channel	36	change_channel
108	Can delete channel	36	delete_channel
109	Can add channel event	37	add_channelevent
110	Can change channel event	37	change_channelevent
111	Can delete channel event	37	delete_channelevent
112	Can add channel session	38	add_channelsession
113	Can change channel session	38	change_channelsession
114	Can delete channel session	38	delete_channelsession
115	Can add sync event	39	add_syncevent
116	Can change sync event	39	change_syncevent
117	Can delete sync event	39	delete_syncevent
118	Can add channel log	40	add_channellog
119	Can change channel log	40	change_channellog
120	Can delete channel log	40	delete_channellog
121	Can add alert	41	add_alert
122	Can change alert	41	change_alert
123	Can delete alert	41	delete_alert
124	Can add channel count	42	add_channelcount
125	Can change channel count	42	change_channelcount
126	Can delete channel count	42	delete_channelcount
127	Can add broadcast	43	add_broadcast
128	Can change broadcast	43	change_broadcast
129	Can delete broadcast	43	delete_broadcast
130	Can add system label count	44	add_systemlabelcount
131	Can change system label count	44	change_systemlabelcount
132	Can delete system label count	44	delete_systemlabelcount
133	Can add label count	45	add_labelcount
134	Can change label count	45	change_labelcount
135	Can delete label count	45	delete_labelcount
136	Can add export messages task	46	add_exportmessagestask
137	Can change export messages task	46	change_exportmessagestask
138	Can delete export messages task	46	delete_exportmessagestask
139	Can add msg	47	add_msg
140	Can change msg	47	change_msg
141	Can delete msg	47	delete_msg
142	Can add label	48	add_label
143	Can change label	48	change_label
144	Can delete label	48	delete_label
145	Can add broadcast recipient	49	add_broadcastrecipient
146	Can change broadcast recipient	49	change_broadcastrecipient
147	Can delete broadcast recipient	49	delete_broadcastrecipient
148	Can add flow node count	50	add_flownodecount
149	Can change flow node count	50	change_flownodecount
150	Can delete flow node count	50	delete_flownodecount
151	Can add flow run	51	add_flowrun
152	Can change flow run	51	change_flowrun
153	Can delete flow run	51	delete_flowrun
154	Can add flow label	52	add_flowlabel
155	Can change flow label	52	change_flowlabel
156	Can delete flow label	52	delete_flowlabel
157	Can add flow start	53	add_flowstart
158	Can change flow start	53	change_flowstart
159	Can delete flow start	53	delete_flowstart
160	Can add action log	54	add_actionlog
161	Can change action log	54	change_actionlog
162	Can delete action log	54	delete_actionlog
163	Can add rule set	55	add_ruleset
164	Can change rule set	55	change_ruleset
165	Can delete rule set	55	delete_ruleset
166	Can add flow step	56	add_flowstep
167	Can change flow step	56	change_flowstep
168	Can delete flow step	56	delete_flowstep
169	Can add flow run count	57	add_flowruncount
170	Can change flow run count	57	change_flowruncount
171	Can delete flow run count	57	delete_flowruncount
172	Can add flow revision	58	add_flowrevision
173	Can change flow revision	58	change_flowrevision
174	Can delete flow revision	58	delete_flowrevision
175	Can add flow path count	59	add_flowpathcount
176	Can change flow path count	59	change_flowpathcount
177	Can delete flow path count	59	delete_flowpathcount
178	Can add action set	60	add_actionset
179	Can change action set	60	change_actionset
180	Can delete action set	60	delete_actionset
181	Can add flow path recent step	61	add_flowpathrecentstep
182	Can change flow path recent step	61	change_flowpathrecentstep
183	Can delete flow path recent step	61	delete_flowpathrecentstep
184	Can add flow	62	add_flow
185	Can change flow	62	change_flow
186	Can delete flow	62	delete_flow
187	Can add export flow results task	63	add_exportflowresultstask
188	Can change export flow results task	63	change_exportflowresultstask
189	Can delete export flow results task	63	delete_exportflowresultstask
190	Can add report	64	add_report
191	Can change report	64	change_report
192	Can delete report	64	delete_report
193	Can add trigger	65	add_trigger
194	Can change trigger	65	change_trigger
195	Can delete trigger	65	delete_trigger
196	Can add campaign event	66	add_campaignevent
197	Can change campaign event	66	change_campaignevent
198	Can delete campaign event	66	delete_campaignevent
199	Can add campaign	67	add_campaign
200	Can change campaign	67	change_campaign
201	Can delete campaign	67	delete_campaign
202	Can add event fire	68	add_eventfire
203	Can change event fire	68	change_eventfire
204	Can delete event fire	68	delete_eventfire
205	Can add ivr call	38	add_ivrcall
206	Can change ivr call	38	change_ivrcall
207	Can delete ivr call	38	delete_ivrcall
208	Can add ussd session	38	add_ussdsession
209	Can change ussd session	38	change_ussdsession
210	Can delete ussd session	38	delete_ussdsession
211	Can add admin boundary	71	add_adminboundary
212	Can change admin boundary	71	change_adminboundary
213	Can delete admin boundary	71	delete_adminboundary
214	Can add boundary alias	72	add_boundaryalias
215	Can change boundary alias	72	change_boundaryalias
216	Can delete boundary alias	72	delete_boundaryalias
217	Can add value	73	add_value
218	Can change value	73	change_value
219	Can delete value	73	delete_value
220	Can add airtime transfer	74	add_airtimetransfer
221	Can change airtime transfer	74	change_airtimetransfer
222	Can delete airtime transfer	74	delete_airtimetransfer
223	Can refresh api token	14	apitoken_refresh
224	Can api campaign	67	campaign_api
225	Can archived campaign	67	campaign_archived
226	Can manage top up	26	topup_manage
227	Can session channel log	40	channellog_session
228	Can api resthook subscriber	17	resthooksubscriber_api
229	Can analytics rule set	55	ruleset_analytics
230	Can choropleth rule set	55	ruleset_choropleth
231	Can map rule set	55	ruleset_map
232	Can results rule set	55	ruleset_results
233	Can api resthook	18	resthook_api
234	Can list resthook	18	resthook_list
235	Can alias admin boundary	71	adminboundary_alias
236	Can api admin boundary	71	adminboundary_api
237	Can boundaries admin boundary	71	adminboundary_boundaries
238	Can geometry admin boundary	71	adminboundary_geometry
239	Can create group	1	group_create
240	Can read group	1	group_read
241	Can update group	1	group_update
242	Can delete group	1	group_delete
243	Can list group	1	group_list
244	Can create user	2	user_create
245	Can read user	2	user_read
246	Can update user	2	user_update
247	Can delete user	2	user_delete
248	Can list user	2	user_list
249	Can create permission	3	permission_create
250	Can read permission	3	permission_read
251	Can update permission	3	permission_update
252	Can delete permission	3	permission_delete
253	Can list permission	3	permission_list
254	Can create content type	4	contenttype_create
255	Can read content type	4	contenttype_read
256	Can update content type	4	contenttype_update
257	Can delete content type	4	contenttype_delete
258	Can list content type	4	contenttype_list
259	Can create session	5	session_create
260	Can read session	5	session_read
261	Can update session	5	session_update
262	Can delete session	5	session_delete
263	Can list session	5	session_list
264	Can create site	6	site_create
265	Can read site	6	site_read
266	Can update site	6	site_update
267	Can delete site	6	site_delete
268	Can list site	6	site_list
269	Can create group object permission	7	groupobjectpermission_create
270	Can read group object permission	7	groupobjectpermission_read
271	Can update group object permission	7	groupobjectpermission_update
272	Can delete group object permission	7	groupobjectpermission_delete
273	Can list group object permission	7	groupobjectpermission_list
274	Can create user object permission	8	userobjectpermission_create
275	Can read user object permission	8	userobjectpermission_read
276	Can update user object permission	8	userobjectpermission_update
277	Can delete user object permission	8	userobjectpermission_delete
278	Can list user object permission	8	userobjectpermission_list
279	Can create Token	9	token_create
280	Can read Token	9	token_read
281	Can update Token	9	token_update
282	Can delete Token	9	token_delete
283	Can list Token	9	token_list
284	Can create import task	10	importtask_create
285	Can read import task	10	importtask_read
286	Can update import task	10	importtask_update
287	Can delete import task	10	importtask_delete
288	Can list import task	10	importtask_list
289	Can create recovery token	11	recoverytoken_create
290	Can read recovery token	11	recoverytoken_read
291	Can update recovery token	11	recoverytoken_update
292	Can delete recovery token	11	recoverytoken_delete
293	Can list recovery token	11	recoverytoken_list
294	Can create failed login	12	failedlogin_create
295	Can read failed login	12	failedlogin_read
296	Can update failed login	12	failedlogin_update
297	Can delete failed login	12	failedlogin_delete
298	Can list failed login	12	failedlogin_list
299	Can create password history	13	passwordhistory_create
300	Can read password history	13	passwordhistory_read
301	Can update password history	13	passwordhistory_update
302	Can delete password history	13	passwordhistory_delete
303	Can list password history	13	passwordhistory_list
304	Can create api token	14	apitoken_create
305	Can read api token	14	apitoken_read
306	Can update api token	14	apitoken_update
307	Can delete api token	14	apitoken_delete
308	Can list api token	14	apitoken_list
309	Can create web hook result	15	webhookresult_create
310	Can read web hook result	15	webhookresult_read
311	Can update web hook result	15	webhookresult_update
312	Can delete web hook result	15	webhookresult_delete
313	Can list web hook result	15	webhookresult_list
314	Can create web hook event	16	webhookevent_create
315	Can read web hook event	16	webhookevent_read
316	Can update web hook event	16	webhookevent_update
317	Can delete web hook event	16	webhookevent_delete
318	Can list web hook event	16	webhookevent_list
319	Can create resthook subscriber	17	resthooksubscriber_create
320	Can read resthook subscriber	17	resthooksubscriber_read
321	Can update resthook subscriber	17	resthooksubscriber_update
322	Can delete resthook subscriber	17	resthooksubscriber_delete
323	Can list resthook subscriber	17	resthooksubscriber_list
324	Can create resthook	18	resthook_create
325	Can read resthook	18	resthook_read
326	Can update resthook	18	resthook_update
327	Can delete resthook	18	resthook_delete
328	Can create video	19	video_create
329	Can read video	19	video_read
330	Can update video	19	video_update
331	Can delete video	19	video_delete
332	Can list video	19	video_list
333	Can create lead	20	lead_create
334	Can read lead	20	lead_read
335	Can update lead	20	lead_update
336	Can delete lead	20	lead_delete
337	Can list lead	20	lead_list
338	Can create schedule	21	schedule_create
339	Can read schedule	21	schedule_read
340	Can update schedule	21	schedule_update
341	Can delete schedule	21	schedule_delete
342	Can list schedule	21	schedule_list
343	Can create invitation	22	invitation_create
344	Can read invitation	22	invitation_read
345	Can update invitation	22	invitation_update
346	Can delete invitation	22	invitation_delete
347	Can list invitation	22	invitation_list
348	Can create org	23	org_create
349	Can read org	23	org_read
350	Can update org	23	org_update
351	Can delete org	23	org_delete
352	Can list org	23	org_list
353	Can create top up credits	24	topupcredits_create
354	Can read top up credits	24	topupcredits_read
355	Can update top up credits	24	topupcredits_update
356	Can delete top up credits	24	topupcredits_delete
357	Can list top up credits	24	topupcredits_list
358	Can create user settings	25	usersettings_create
359	Can read user settings	25	usersettings_read
360	Can update user settings	25	usersettings_update
361	Can delete user settings	25	usersettings_delete
362	Can list user settings	25	usersettings_list
363	Can create top up	26	topup_create
364	Can read top up	26	topup_read
365	Can update top up	26	topup_update
366	Can delete top up	26	topup_delete
367	Can list top up	26	topup_list
368	Can create language	27	language_create
369	Can read language	27	language_read
370	Can update language	27	language_update
371	Can delete language	27	language_delete
372	Can list language	27	language_list
373	Can create credit alert	28	creditalert_create
374	Can read credit alert	28	creditalert_read
375	Can update credit alert	28	creditalert_update
376	Can delete credit alert	28	creditalert_delete
377	Can list credit alert	28	creditalert_list
378	Can create debit	29	debit_create
379	Can read debit	29	debit_read
380	Can update debit	29	debit_update
381	Can delete debit	29	debit_delete
382	Can list debit	29	debit_list
383	Can create contact field	30	contactfield_create
384	Can read contact field	30	contactfield_read
385	Can update contact field	30	contactfield_update
386	Can delete contact field	30	contactfield_delete
387	Can list contact field	30	contactfield_list
388	Can create contact group	31	contactgroup_create
389	Can read contact group	31	contactgroup_read
390	Can update contact group	31	contactgroup_update
391	Can delete contact group	31	contactgroup_delete
392	Can list contact group	31	contactgroup_list
393	Can create export contacts task	32	exportcontactstask_create
394	Can read export contacts task	32	exportcontactstask_read
395	Can update export contacts task	32	exportcontactstask_update
396	Can delete export contacts task	32	exportcontactstask_delete
397	Can list export contacts task	32	exportcontactstask_list
398	Can create contact	33	contact_create
399	Can read contact	33	contact_read
400	Can update contact	33	contact_update
401	Can delete contact	33	contact_delete
402	Can list contact	33	contact_list
403	Can create contact urn	34	contacturn_create
404	Can read contact urn	34	contacturn_read
405	Can update contact urn	34	contacturn_update
406	Can delete contact urn	34	contacturn_delete
407	Can list contact urn	34	contacturn_list
408	Can create contact group count	35	contactgroupcount_create
409	Can read contact group count	35	contactgroupcount_read
410	Can update contact group count	35	contactgroupcount_update
411	Can delete contact group count	35	contactgroupcount_delete
412	Can list contact group count	35	contactgroupcount_list
413	Can create channel	36	channel_create
414	Can read channel	36	channel_read
415	Can update channel	36	channel_update
416	Can delete channel	36	channel_delete
417	Can list channel	36	channel_list
418	Can create channel event	37	channelevent_create
419	Can read channel event	37	channelevent_read
420	Can update channel event	37	channelevent_update
421	Can delete channel event	37	channelevent_delete
422	Can list channel event	37	channelevent_list
423	Can create channel session	38	channelsession_create
424	Can read channel session	38	channelsession_read
425	Can update channel session	38	channelsession_update
426	Can delete channel session	38	channelsession_delete
427	Can list channel session	38	channelsession_list
428	Can create sync event	39	syncevent_create
429	Can read sync event	39	syncevent_read
430	Can update sync event	39	syncevent_update
431	Can delete sync event	39	syncevent_delete
432	Can list sync event	39	syncevent_list
433	Can create channel log	40	channellog_create
434	Can read channel log	40	channellog_read
435	Can update channel log	40	channellog_update
436	Can delete channel log	40	channellog_delete
437	Can list channel log	40	channellog_list
438	Can create alert	41	alert_create
439	Can read alert	41	alert_read
440	Can update alert	41	alert_update
441	Can delete alert	41	alert_delete
442	Can list alert	41	alert_list
443	Can create channel count	42	channelcount_create
444	Can read channel count	42	channelcount_read
445	Can update channel count	42	channelcount_update
446	Can delete channel count	42	channelcount_delete
447	Can list channel count	42	channelcount_list
448	Can create broadcast	43	broadcast_create
449	Can read broadcast	43	broadcast_read
450	Can update broadcast	43	broadcast_update
451	Can delete broadcast	43	broadcast_delete
452	Can list broadcast	43	broadcast_list
453	Can create system label count	44	systemlabelcount_create
454	Can read system label count	44	systemlabelcount_read
455	Can update system label count	44	systemlabelcount_update
456	Can delete system label count	44	systemlabelcount_delete
457	Can list system label count	44	systemlabelcount_list
458	Can create label count	45	labelcount_create
459	Can read label count	45	labelcount_read
460	Can update label count	45	labelcount_update
461	Can delete label count	45	labelcount_delete
462	Can list label count	45	labelcount_list
463	Can create export messages task	46	exportmessagestask_create
464	Can read export messages task	46	exportmessagestask_read
465	Can update export messages task	46	exportmessagestask_update
466	Can delete export messages task	46	exportmessagestask_delete
467	Can list export messages task	46	exportmessagestask_list
468	Can create msg	47	msg_create
469	Can read msg	47	msg_read
470	Can update msg	47	msg_update
471	Can delete msg	47	msg_delete
472	Can list msg	47	msg_list
473	Can create label	48	label_create
474	Can read label	48	label_read
475	Can update label	48	label_update
476	Can delete label	48	label_delete
477	Can list label	48	label_list
478	Can create broadcast recipient	49	broadcastrecipient_create
479	Can read broadcast recipient	49	broadcastrecipient_read
480	Can update broadcast recipient	49	broadcastrecipient_update
481	Can delete broadcast recipient	49	broadcastrecipient_delete
482	Can list broadcast recipient	49	broadcastrecipient_list
483	Can create flow node count	50	flownodecount_create
484	Can read flow node count	50	flownodecount_read
485	Can update flow node count	50	flownodecount_update
486	Can delete flow node count	50	flownodecount_delete
487	Can list flow node count	50	flownodecount_list
488	Can create flow run	51	flowrun_create
489	Can read flow run	51	flowrun_read
490	Can update flow run	51	flowrun_update
491	Can delete flow run	51	flowrun_delete
492	Can list flow run	51	flowrun_list
493	Can create flow label	52	flowlabel_create
494	Can read flow label	52	flowlabel_read
495	Can update flow label	52	flowlabel_update
496	Can delete flow label	52	flowlabel_delete
497	Can list flow label	52	flowlabel_list
498	Can create flow start	53	flowstart_create
499	Can read flow start	53	flowstart_read
500	Can update flow start	53	flowstart_update
501	Can delete flow start	53	flowstart_delete
502	Can list flow start	53	flowstart_list
503	Can create action log	54	actionlog_create
504	Can read action log	54	actionlog_read
505	Can update action log	54	actionlog_update
506	Can delete action log	54	actionlog_delete
507	Can list action log	54	actionlog_list
508	Can create rule set	55	ruleset_create
509	Can read rule set	55	ruleset_read
510	Can update rule set	55	ruleset_update
511	Can delete rule set	55	ruleset_delete
512	Can list rule set	55	ruleset_list
513	Can create flow step	56	flowstep_create
514	Can read flow step	56	flowstep_read
515	Can update flow step	56	flowstep_update
516	Can delete flow step	56	flowstep_delete
517	Can list flow step	56	flowstep_list
518	Can create flow run count	57	flowruncount_create
519	Can read flow run count	57	flowruncount_read
520	Can update flow run count	57	flowruncount_update
521	Can delete flow run count	57	flowruncount_delete
522	Can list flow run count	57	flowruncount_list
523	Can create flow revision	58	flowrevision_create
524	Can read flow revision	58	flowrevision_read
525	Can update flow revision	58	flowrevision_update
526	Can delete flow revision	58	flowrevision_delete
527	Can list flow revision	58	flowrevision_list
528	Can create flow path count	59	flowpathcount_create
529	Can read flow path count	59	flowpathcount_read
530	Can update flow path count	59	flowpathcount_update
531	Can delete flow path count	59	flowpathcount_delete
532	Can list flow path count	59	flowpathcount_list
533	Can create action set	60	actionset_create
534	Can read action set	60	actionset_read
535	Can update action set	60	actionset_update
536	Can delete action set	60	actionset_delete
537	Can list action set	60	actionset_list
538	Can create flow path recent step	61	flowpathrecentstep_create
539	Can read flow path recent step	61	flowpathrecentstep_read
540	Can update flow path recent step	61	flowpathrecentstep_update
541	Can delete flow path recent step	61	flowpathrecentstep_delete
542	Can list flow path recent step	61	flowpathrecentstep_list
543	Can create flow	62	flow_create
544	Can read flow	62	flow_read
545	Can update flow	62	flow_update
546	Can delete flow	62	flow_delete
547	Can list flow	62	flow_list
548	Can create export flow results task	63	exportflowresultstask_create
549	Can read export flow results task	63	exportflowresultstask_read
550	Can update export flow results task	63	exportflowresultstask_update
551	Can delete export flow results task	63	exportflowresultstask_delete
552	Can list export flow results task	63	exportflowresultstask_list
553	Can create report	64	report_create
554	Can read report	64	report_read
555	Can update report	64	report_update
556	Can delete report	64	report_delete
557	Can list report	64	report_list
558	Can create trigger	65	trigger_create
559	Can read trigger	65	trigger_read
560	Can update trigger	65	trigger_update
561	Can delete trigger	65	trigger_delete
562	Can list trigger	65	trigger_list
563	Can create campaign event	66	campaignevent_create
564	Can read campaign event	66	campaignevent_read
565	Can update campaign event	66	campaignevent_update
566	Can delete campaign event	66	campaignevent_delete
567	Can list campaign event	66	campaignevent_list
568	Can create campaign	67	campaign_create
569	Can read campaign	67	campaign_read
570	Can update campaign	67	campaign_update
571	Can delete campaign	67	campaign_delete
572	Can list campaign	67	campaign_list
573	Can create event fire	68	eventfire_create
574	Can read event fire	68	eventfire_read
575	Can update event fire	68	eventfire_update
576	Can delete event fire	68	eventfire_delete
577	Can list event fire	68	eventfire_list
578	Can create ivr call	69	ivrcall_create
579	Can read ivr call	69	ivrcall_read
580	Can update ivr call	69	ivrcall_update
581	Can delete ivr call	69	ivrcall_delete
582	Can list ivr call	69	ivrcall_list
583	Can create ussd session	70	ussdsession_create
584	Can read ussd session	70	ussdsession_read
585	Can update ussd session	70	ussdsession_update
586	Can delete ussd session	70	ussdsession_delete
587	Can list ussd session	70	ussdsession_list
588	Can create admin boundary	71	adminboundary_create
589	Can read admin boundary	71	adminboundary_read
590	Can update admin boundary	71	adminboundary_update
591	Can delete admin boundary	71	adminboundary_delete
592	Can list admin boundary	71	adminboundary_list
593	Can create boundary alias	72	boundaryalias_create
594	Can read boundary alias	72	boundaryalias_read
595	Can update boundary alias	72	boundaryalias_update
596	Can delete boundary alias	72	boundaryalias_delete
597	Can list boundary alias	72	boundaryalias_list
598	Can create value	73	value_create
599	Can read value	73	value_read
600	Can update value	73	value_update
601	Can delete value	73	value_delete
602	Can list value	73	value_list
603	Can create airtime transfer	74	airtimetransfer_create
604	Can read airtime transfer	74	airtimetransfer_read
605	Can update airtime transfer	74	airtimetransfer_update
606	Can delete airtime transfer	74	airtimetransfer_delete
607	Can list airtime transfer	74	airtimetransfer_list
608	Can api contact field	30	contactfield_api
609	Can json contact field	30	contactfield_json
610	Can managefields contact field	30	contactfield_managefields
611	Can api contact	33	contact_api
612	Can block contact	33	contact_block
613	Can blocked contact	33	contact_blocked
614	Can break_anon contact	33	contact_break_anon
615	Can customize contact	33	contact_customize
616	Can export contact	33	contact_export
617	Can stopped contact	33	contact_stopped
618	Can filter contact	33	contact_filter
619	Can history contact	33	contact_history
620	Can import contact	33	contact_import
621	Can omnibox contact	33	contact_omnibox
622	Can unblock contact	33	contact_unblock
623	Can unstop contact	33	contact_unstop
624	Can update_fields contact	33	contact_update_fields
625	Can update_fields_input contact	33	contact_update_fields_input
626	Can api channel	36	channel_api
627	Can bulk_sender_options channel	36	channel_bulk_sender_options
628	Can claim channel	36	channel_claim
629	Can claim_africas_talking channel	36	channel_claim_africas_talking
630	Can claim_android channel	36	channel_claim_android
631	Can claim_blackmyna channel	36	channel_claim_blackmyna
632	Can claim_chikka channel	36	channel_claim_chikka
633	Can claim_clickatell channel	36	channel_claim_clickatell
634	Can claim_dart_media channel	36	channel_claim_dart_media
635	Can claim_external channel	36	channel_claim_external
636	Can claim_facebook channel	36	channel_claim_facebook
637	Can claim_fcm channel	36	channel_claim_fcm
638	Can claim_globe channel	36	channel_claim_globe
639	Can claim_high_connection channel	36	channel_claim_high_connection
640	Can claim_hub9 channel	36	channel_claim_hub9
641	Can claim_infobip channel	36	channel_claim_infobip
642	Can claim_jasmin channel	36	channel_claim_jasmin
643	Can claim_junebug channel	36	channel_claim_junebug
644	Can claim_kannel channel	36	channel_claim_kannel
645	Can claim_line channel	36	channel_claim_line
646	Can claim_macrokiosk channel	36	channel_claim_macrokiosk
647	Can claim_m3tech channel	36	channel_claim_m3tech
648	Can claim_mblox channel	36	channel_claim_mblox
649	Can claim_nexmo channel	36	channel_claim_nexmo
650	Can claim_plivo channel	36	channel_claim_plivo
651	Can claim_red_rabbit channel	36	channel_claim_red_rabbit
652	Can claim_shaqodoon channel	36	channel_claim_shaqodoon
653	Can claim_smscentral channel	36	channel_claim_smscentral
654	Can claim_start channel	36	channel_claim_start
655	Can claim_telegram channel	36	channel_claim_telegram
656	Can claim_twilio channel	36	channel_claim_twilio
657	Can claim_twiml_api channel	36	channel_claim_twiml_api
658	Can claim_twilio_messaging_service channel	36	channel_claim_twilio_messaging_service
659	Can claim_twitter channel	36	channel_claim_twitter
660	Can claim_verboice channel	36	channel_claim_verboice
661	Can claim_viber channel	36	channel_claim_viber
662	Can claim_viber_public channel	36	channel_claim_viber_public
663	Can create_viber channel	36	channel_create_viber
664	Can claim_vumi channel	36	channel_claim_vumi
665	Can claim_vumi_ussd channel	36	channel_claim_vumi_ussd
666	Can claim_yo channel	36	channel_claim_yo
667	Can claim_zenvia channel	36	channel_claim_zenvia
668	Can configuration channel	36	channel_configuration
669	Can create_bulk_sender channel	36	channel_create_bulk_sender
670	Can create_caller channel	36	channel_create_caller
671	Can errors channel	36	channel_errors
672	Can facebook_whitelist channel	36	channel_facebook_whitelist
673	Can search_nexmo channel	36	channel_search_nexmo
674	Can search_numbers channel	36	channel_search_numbers
675	Can start ivr call	69	ivrcall_start
676	Can api channel event	37	channelevent_api
677	Can calls channel event	37	channelevent_calls
678	Can api flow start	53	flowstart_api
679	Can archived trigger	65	trigger_archived
680	Can catchall trigger	65	trigger_catchall
681	Can follow trigger	65	trigger_follow
682	Can inbound_call trigger	65	trigger_inbound_call
683	Can keyword trigger	65	trigger_keyword
684	Can missed_call trigger	65	trigger_missed_call
685	Can new_conversation trigger	65	trigger_new_conversation
686	Can referral trigger	65	trigger_referral
687	Can register trigger	65	trigger_register
688	Can schedule trigger	65	trigger_schedule
689	Can ussd trigger	65	trigger_ussd
690	Can phone user settings	25	usersettings_phone
691	Can api label	48	label_api
692	Can create_folder label	48	label_create_folder
693	Can api msg	47	msg_api
694	Can archive msg	47	msg_archive
695	Can archived msg	47	msg_archived
696	Can export msg	47	msg_export
697	Can failed msg	47	msg_failed
698	Can filter msg	47	msg_filter
699	Can flow msg	47	msg_flow
700	Can inbox msg	47	msg_inbox
701	Can label msg	47	msg_label
702	Can outbox msg	47	msg_outbox
703	Can sent msg	47	msg_sent
704	Can test msg	47	msg_test
705	Can api broadcast	43	broadcast_api
706	Can detail broadcast	43	broadcast_detail
707	Can schedule broadcast	43	broadcast_schedule
708	Can schedule_list broadcast	43	broadcast_schedule_list
709	Can schedule_read broadcast	43	broadcast_schedule_read
710	Can send broadcast	43	broadcast_send
711	Can api campaign event	66	campaignevent_api
712	Can activity flow	62	flow_activity
713	Can activity_chart flow	62	flow_activity_chart
714	Can activity_list flow	62	flow_activity_list
715	Can analytics flow	62	flow_analytics
716	Can api flow	62	flow_api
717	Can archived flow	62	flow_archived
718	Can broadcast flow	62	flow_broadcast
719	Can campaign flow	62	flow_campaign
720	Can completion flow	62	flow_completion
721	Can copy flow	62	flow_copy
722	Can editor flow	62	flow_editor
723	Can export flow	62	flow_export
724	Can export_results flow	62	flow_export_results
725	Can filter flow	62	flow_filter
726	Can json flow	62	flow_json
727	Can recent_messages flow	62	flow_recent_messages
728	Can results flow	62	flow_results
729	Can revisions flow	62	flow_revisions
730	Can run_table flow	62	flow_run_table
731	Can simulate flow	62	flow_simulate
732	Can upload_action_recording flow	62	flow_upload_action_recording
733	Can upload_media_action flow	62	flow_upload_media_action
734	Can api web hook event	16	webhookevent_api
735	Can accounts org	23	org_accounts
736	Can smtp_server org	23	org_smtp_server
737	Can api org	23	org_api
738	Can country org	23	org_country
739	Can clear_cache org	23	org_clear_cache
740	Can create_login org	23	org_create_login
741	Can create_sub_org org	23	org_create_sub_org
742	Can download org	23	org_download
743	Can edit org	23	org_edit
744	Can edit_sub_org org	23	org_edit_sub_org
745	Can export org	23	org_export
746	Can grant org	23	org_grant
747	Can home org	23	org_home
748	Can import org	23	org_import
749	Can join org	23	org_join
750	Can languages org	23	org_languages
751	Can manage org	23	org_manage
752	Can manage_accounts org	23	org_manage_accounts
753	Can manage_accounts_sub_org org	23	org_manage_accounts_sub_org
754	Can nexmo_configuration org	23	org_nexmo_configuration
755	Can nexmo_account org	23	org_nexmo_account
756	Can nexmo_connect org	23	org_nexmo_connect
757	Can plivo_connect org	23	org_plivo_connect
758	Can profile org	23	org_profile
759	Can resthooks org	23	org_resthooks
760	Can service org	23	org_service
761	Can signup org	23	org_signup
762	Can sub_orgs org	23	org_sub_orgs
763	Can surveyor org	23	org_surveyor
764	Can transfer_credits org	23	org_transfer_credits
765	Can transfer_to_account org	23	org_transfer_to_account
766	Can trial org	23	org_trial
767	Can twilio_account org	23	org_twilio_account
768	Can twilio_connect org	23	org_twilio_connect
769	Can webhook org	23	org_webhook
770	Can api contact group	31	contactgroup_api
\.


--
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_permission_id_seq', 770, true);


--
-- Data for Name: auth_user; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_user (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined) FROM stdin;
1	!2sROkfWQykkuBV2pklX1drmvWZKLtATwBpCE5yQR	\N	f	AnonymousUser				f	t	2017-07-27 20:39:45.16374+00
\.


--
-- Data for Name: auth_user_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_user_groups (id, user_id, group_id) FROM stdin;
\.


--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_user_groups_id_seq', 1, false);


--
-- Name: auth_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_user_id_seq', 1, true);


--
-- Data for Name: auth_user_user_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_user_user_permissions (id, user_id, permission_id) FROM stdin;
\.


--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_user_user_permissions_id_seq', 1, false);


--
-- Data for Name: authtoken_token; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY authtoken_token (key, created, user_id) FROM stdin;
\.


--
-- Data for Name: campaigns_campaign; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY campaigns_campaign (id, is_active, created_on, modified_on, uuid, name, is_archived, created_by_id, group_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: campaigns_campaign_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('campaigns_campaign_id_seq', 1, false);


--
-- Data for Name: campaigns_campaignevent; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY campaigns_campaignevent (id, is_active, created_on, modified_on, uuid, "offset", unit, event_type, delivery_hour, campaign_id, created_by_id, flow_id, modified_by_id, relative_to_id, message) FROM stdin;
\.


--
-- Name: campaigns_campaignevent_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('campaigns_campaignevent_id_seq', 1, false);


--
-- Data for Name: campaigns_eventfire; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY campaigns_eventfire (id, scheduled, fired, contact_id, event_id) FROM stdin;
\.


--
-- Name: campaigns_eventfire_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('campaigns_eventfire_id_seq', 1, false);


--
-- Data for Name: channels_alert; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY channels_alert (id, is_active, created_on, modified_on, alert_type, ended_on, channel_id, created_by_id, modified_by_id, sync_event_id) FROM stdin;
\.


--
-- Name: channels_alert_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('channels_alert_id_seq', 1, false);


--
-- Data for Name: channels_channel; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY channels_channel (id, is_active, created_on, modified_on, uuid, channel_type, name, address, country, gcm_id, claim_code, secret, last_seen, device, os, alert_email, config, scheme, role, bod, created_by_id, modified_by_id, org_id, parent_id) FROM stdin;
\.


--
-- Name: channels_channel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('channels_channel_id_seq', 1, false);


--
-- Data for Name: channels_channelcount; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY channels_channelcount (id, count_type, day, count, channel_id, is_squashed) FROM stdin;
\.


--
-- Name: channels_channelcount_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('channels_channelcount_id_seq', 1, false);


--
-- Data for Name: channels_channelevent; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY channels_channelevent (id, event_type, "time", duration, created_on, is_active, channel_id, contact_id, contact_urn_id, org_id) FROM stdin;
\.


--
-- Name: channels_channelevent_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('channels_channelevent_id_seq', 1, false);


--
-- Data for Name: channels_channellog; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY channels_channellog (id, description, is_error, url, method, request, response, response_status, created_on, request_time, channel_id, msg_id, session_id) FROM stdin;
\.


--
-- Name: channels_channellog_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('channels_channellog_id_seq', 1, false);


--
-- Data for Name: channels_channelsession; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY channels_channelsession (id, is_active, created_on, modified_on, external_id, status, direction, started_on, ended_on, session_type, duration, channel_id, contact_id, contact_urn_id, created_by_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: channels_channelsession_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('channels_channelsession_id_seq', 1, false);


--
-- Data for Name: channels_syncevent; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY channels_syncevent (id, is_active, created_on, modified_on, power_source, power_status, power_level, network_type, lifetime, pending_message_count, retry_message_count, incoming_command_count, outgoing_command_count, channel_id, created_by_id, modified_by_id) FROM stdin;
\.


--
-- Name: channels_syncevent_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('channels_syncevent_id_seq', 1, false);


--
-- Data for Name: contacts_contact; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY contacts_contact (id, is_active, created_on, modified_on, uuid, name, is_blocked, is_test, is_stopped, language, created_by_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: contacts_contact_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contacts_contact_id_seq', 1, false);


--
-- Data for Name: contacts_contactfield; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY contacts_contactfield (id, is_active, created_on, modified_on, label, key, value_type, show_in_table, created_by_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: contacts_contactfield_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contacts_contactfield_id_seq', 1, false);


--
-- Data for Name: contacts_contactgroup; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY contacts_contactgroup (id, is_active, created_on, modified_on, uuid, name, group_type, query, created_by_id, import_task_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Data for Name: contacts_contactgroup_contacts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY contacts_contactgroup_contacts (id, contactgroup_id, contact_id) FROM stdin;
\.


--
-- Name: contacts_contactgroup_contacts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contacts_contactgroup_contacts_id_seq', 1, false);


--
-- Name: contacts_contactgroup_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contacts_contactgroup_id_seq', 1, false);


--
-- Data for Name: contacts_contactgroup_query_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY contacts_contactgroup_query_fields (id, contactgroup_id, contactfield_id) FROM stdin;
\.


--
-- Name: contacts_contactgroup_query_fields_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contacts_contactgroup_query_fields_id_seq', 1, false);


--
-- Data for Name: contacts_contactgroupcount; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY contacts_contactgroupcount (id, count, group_id, is_squashed) FROM stdin;
\.


--
-- Name: contacts_contactgroupcount_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contacts_contactgroupcount_id_seq', 1, false);


--
-- Data for Name: contacts_contacturn; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY contacts_contacturn (id, urn, path, scheme, priority, channel_id, contact_id, org_id, auth) FROM stdin;
\.


--
-- Name: contacts_contacturn_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contacts_contacturn_id_seq', 1, false);


--
-- Data for Name: contacts_exportcontactstask; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY contacts_exportcontactstask (id, is_active, created_on, modified_on, uuid, created_by_id, group_id, modified_by_id, org_id, status, search) FROM stdin;
\.


--
-- Name: contacts_exportcontactstask_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contacts_exportcontactstask_id_seq', 1, false);


--
-- Data for Name: csv_imports_importtask; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY csv_imports_importtask (id, is_active, created_on, modified_on, csv_file, model_class, import_params, import_log, import_results, task_id, created_by_id, modified_by_id, task_status) FROM stdin;
\.


--
-- Name: csv_imports_importtask_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('csv_imports_importtask_id_seq', 1, false);


--
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY django_content_type (id, app_label, model) FROM stdin;
1	auth	group
2	auth	user
3	auth	permission
4	contenttypes	contenttype
5	sessions	session
6	sites	site
7	guardian	groupobjectpermission
8	guardian	userobjectpermission
9	authtoken	token
10	csv_imports	importtask
11	users	recoverytoken
12	users	failedlogin
13	users	passwordhistory
14	api	apitoken
15	api	webhookresult
16	api	webhookevent
17	api	resthooksubscriber
18	api	resthook
19	public	video
20	public	lead
21	schedules	schedule
22	orgs	invitation
23	orgs	org
24	orgs	topupcredits
25	orgs	usersettings
26	orgs	topup
27	orgs	language
28	orgs	creditalert
29	orgs	debit
30	contacts	contactfield
31	contacts	contactgroup
32	contacts	exportcontactstask
33	contacts	contact
34	contacts	contacturn
35	contacts	contactgroupcount
36	channels	channel
37	channels	channelevent
38	channels	channelsession
39	channels	syncevent
40	channels	channellog
41	channels	alert
42	channels	channelcount
43	msgs	broadcast
44	msgs	systemlabelcount
45	msgs	labelcount
46	msgs	exportmessagestask
47	msgs	msg
48	msgs	label
49	msgs	broadcastrecipient
50	flows	flownodecount
51	flows	flowrun
52	flows	flowlabel
53	flows	flowstart
54	flows	actionlog
55	flows	ruleset
56	flows	flowstep
57	flows	flowruncount
58	flows	flowrevision
59	flows	flowpathcount
60	flows	actionset
61	flows	flowpathrecentstep
62	flows	flow
63	flows	exportflowresultstask
64	reports	report
65	triggers	trigger
66	campaigns	campaignevent
67	campaigns	campaign
68	campaigns	eventfire
69	ivr	ivrcall
70	ussd	ussdsession
71	locations	adminboundary
72	locations	boundaryalias
73	values	value
74	airtime	airtimetransfer
\.


--
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('django_content_type_id_seq', 74, true);


--
-- Data for Name: django_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY django_migrations (id, app, name, applied) FROM stdin;
1	contenttypes	0001_initial	2017-07-27 20:39:03.247739+00
2	auth	0001_initial	2017-07-27 20:39:03.406995+00
3	locations	0006_reset_1	2017-07-27 20:39:03.515368+00
4	orgs	0029_reset_1	2017-07-27 20:39:04.09504+00
5	contacts	0046_reset_1	2017-07-27 20:39:04.246536+00
6	channels	0050_reset_1	2017-07-27 20:39:04.392897+00
7	airtime	0003_reset_1	2017-07-27 20:39:04.409345+00
8	airtime	0004_reset_2	2017-07-27 20:39:04.462709+00
9	airtime	0005_reset_3	2017-07-27 20:39:04.713828+00
10	airtime	0006_reset_4	2017-07-27 20:39:04.766521+00
11	airtime	0007_auto_20170228_0837	2017-07-27 20:39:04.857254+00
12	schedules	0003_reset_1	2017-07-27 20:39:04.923172+00
13	flows	0079_reset_1	2017-07-27 20:39:05.146162+00
14	channels	0051_reset_2	2017-07-27 20:39:05.311012+00
15	channels	0052_reset_3	2017-07-27 20:39:05.429304+00
16	msgs	0075_reset_1	2017-07-27 20:39:06.913518+00
17	channels	0053_reset_4	2017-07-27 20:39:08.536815+00
18	flows	0080_reset_2	2017-07-27 20:39:12.649501+00
19	flows	0081_install_triggers	2017-07-27 20:39:12.668083+00
20	flows	0082_install_indexes	2017-07-27 20:39:12.705016+00
21	flows	0083_flowpathrecentstep	2017-07-27 20:39:12.847584+00
22	flows	0084_populate_recent_steps	2017-07-27 20:39:12.855506+00
23	flows	0085_auto_20170112_1629	2017-07-27 20:39:13.096424+00
24	flows	0086_is_squashed	2017-07-27 20:39:13.433619+00
25	flows	0087_fix_open_ended_ruleset_with_timeout	2017-07-27 20:39:13.457646+00
26	flows	0088_drop_squash_functions	2017-07-27 20:39:13.470023+00
27	flows	0089_baseexporttask_1	2017-07-27 20:39:13.801761+00
28	flows	0090_baseexporttask_2	2017-07-27 20:39:14.142554+00
29	flows	0091_auto_20170228_0837	2017-07-27 20:39:15.053372+00
30	flows	0092_flowstart_include_active	2017-07-27 20:39:15.165729+00
31	flows	0093_flownodecount	2017-07-27 20:39:15.289767+00
32	flows	0094_update_step_trigger	2017-07-27 20:39:15.299828+00
33	flows	0095_clear_old_flow_stat_cache	2017-07-27 20:39:15.312666+00
34	flows	0096_populate_flownodecount	2017-07-27 20:39:15.322422+00
35	api	0009_reset_1	2017-07-27 20:39:15.504567+00
36	api	0010_reset_2	2017-07-27 20:39:15.961252+00
37	api	0011_reset_3	2017-07-27 20:39:17.398977+00
38	api	0012_auto_20170228_0837	2017-07-27 20:39:18.378563+00
39	api	0013_webhookresult_request_time	2017-07-27 20:39:18.48544+00
40	api	0014_auto_20170410_0731	2017-07-27 20:39:18.963748+00
41	contenttypes	0002_remove_content_type_name	2017-07-27 20:39:19.310208+00
42	auth	0002_alter_permission_name_max_length	2017-07-27 20:39:19.540461+00
43	auth	0003_alter_user_email_max_length	2017-07-27 20:39:19.656846+00
44	auth	0004_alter_user_username_opts	2017-07-27 20:39:19.778303+00
45	auth	0005_alter_user_last_login_null	2017-07-27 20:39:19.914815+00
46	auth	0006_require_contenttypes_0002	2017-07-27 20:39:19.924935+00
47	auth	0007_alter_validators_add_error_messages	2017-07-27 20:39:20.095237+00
48	auth	0008_alter_user_username_max_length	2017-07-27 20:39:20.227573+00
49	auth_tweaks	0001_initial	2017-07-27 20:39:20.242861+00
50	authtoken	0001_initial	2017-07-27 20:39:20.492213+00
51	authtoken	0002_auto_20160226_1747	2017-07-27 20:39:20.991349+00
52	campaigns	0010_reset_1	2017-07-27 20:39:21.05434+00
53	campaigns	0011_reset_2	2017-07-27 20:39:21.759943+00
54	campaigns	0012_reset_3	2017-07-27 20:39:22.565228+00
55	campaigns	0013_reset_4	2017-07-27 20:39:22.681668+00
56	campaigns	0014_auto_20170228_0837	2017-07-27 20:39:23.254038+00
57	campaigns	0015_campaignevent_message_new	2017-07-27 20:39:23.382588+00
58	campaigns	0016_remove_campaignevent_message	2017-07-27 20:39:23.743978+00
59	campaigns	0017_auto_20170508_1540	2017-07-27 20:39:23.881729+00
60	channels	0054_install_triggers	2017-07-27 20:39:23.892611+00
61	channels	0055_install_indexes	2017-07-27 20:39:23.910508+00
62	channels	0056_remove_child_sessions	2017-07-27 20:39:23.923654+00
63	channels	0057_remove_channelsession_parent_and_flow	2017-07-27 20:39:24.210646+00
64	channels	0058_add_junebug_channel_type	2017-07-27 20:39:24.341463+00
65	channels	0059_update_nexmo_channels_roles	2017-07-27 20:39:24.35019+00
66	channels	0060_auto_20170110_0904	2017-07-27 20:39:24.726642+00
67	channels	0061_channelcount_is_squashed	2017-07-27 20:39:24.87866+00
68	channels	0062_auto_20170208_1450	2017-07-27 20:39:24.995068+00
69	channels	0063_auto_20170222_2332	2017-07-27 20:39:25.005361+00
70	channels	0064_recalculate_channellog_counts	2017-07-27 20:39:25.017492+00
71	channels	0065_auto_20170228_0837	2017-07-27 20:39:26.150013+00
72	channels	0066_auto_20170306_1713	2017-07-27 20:39:26.260285+00
73	channels	0067_auto_20170306_2042	2017-07-27 20:39:26.369028+00
74	channels	0068_junebug_ussd_channel_type	2017-07-27 20:39:26.481163+00
75	channels	0069_auto_20170427_1241	2017-07-27 20:39:26.595819+00
76	channels	0070_auto_20170428_1135	2017-07-27 20:39:26.825598+00
77	csv_imports	0001_initial	2017-07-27 20:39:26.953228+00
78	csv_imports	0002_auto_20161118_1920	2017-07-27 20:39:27.076732+00
79	csv_imports	0003_importtask_task_status	2017-07-27 20:39:27.210935+00
80	contacts	0047_reset_2	2017-07-27 20:39:29.901625+00
81	contacts	0048_install_triggers	2017-07-27 20:39:29.9265+00
82	contacts	0049_install_indexes	2017-07-27 20:39:29.952017+00
83	contacts	0050_contactgroupcount_is_squashed	2017-07-27 20:39:30.108541+00
84	contacts	0051_baseexporttask_1	2017-07-27 20:39:30.535068+00
85	contacts	0052_baseexporttask_2	2017-07-27 20:39:30.933999+00
86	contacts	0053_auto_20170208_1450	2017-07-27 20:39:31.058391+00
87	contacts	0054_contacturn_auth	2017-07-27 20:39:31.178296+00
88	contacts	0055_auto_20170228_0837	2017-07-27 20:39:32.368443+00
89	contacts	0056_exportcontactstask_search	2017-07-27 20:39:32.493976+00
90	contacts	0057_omnibox_indexes	2017-07-27 20:39:32.518064+00
91	contacts	0058_remove_contactgroup_count	2017-07-27 20:39:32.639397+00
92	csv_imports	0004_auto_20170223_0917	2017-07-27 20:39:32.99795+00
93	flows	0097_interrupt_runs_for_archived_flows	2017-07-27 20:39:33.009113+00
94	guardian	0001_initial	2017-07-27 20:39:33.544618+00
95	ivr	0013_reset_1	2017-07-27 20:39:33.553923+00
96	ivr	0014_add_twilio_status_callback	2017-07-27 20:39:33.561776+00
97	locations	0007_reset_2	2017-07-27 20:39:33.951416+00
98	locations	0008_auto_20170221_1424	2017-07-27 20:39:33.992818+00
99	locations	0009_auto_20170228_0837	2017-07-27 20:39:34.253383+00
100	orgs	0030_install_triggers	2017-07-27 20:39:34.26435+00
101	orgs	0031_is_squashed	2017-07-27 20:39:34.673044+00
102	orgs	0032_fix_org_with_nexmo_config	2017-07-27 20:39:34.693642+00
103	orgs	0033_fix_org_with_nexmo_config_absolute_urls	2017-07-27 20:39:34.705896+00
104	orgs	0034_auto_20170228_0837	2017-07-27 20:39:36.153132+00
105	msgs	0076_install_triggers	2017-07-27 20:39:36.169128+00
106	msgs	0077_install_indexes	2017-07-27 20:39:36.197666+00
107	msgs	0078_msg_session	2017-07-27 20:39:36.332169+00
108	msgs	0079_populate_msg_session	2017-07-27 20:39:36.344249+00
109	msgs	0080_systemlabel_is_squashed	2017-07-27 20:39:36.49176+00
110	msgs	0081_baseexporttask_1	2017-07-27 20:39:37.0279+00
111	msgs	0082_baseexporttask_2	2017-07-27 20:39:37.301917+00
112	msgs	0083_auto_20170228_0837	2017-07-27 20:39:38.052029+00
113	msgs	0084_broadcast_media_dict	2017-07-27 20:39:38.186131+00
114	msgs	0085_auto_20170315_1245	2017-07-27 20:39:38.430101+00
115	msgs	0086_label_counts	2017-07-27 20:39:38.703273+00
116	msgs	0087_remove_label_visible_count	2017-07-27 20:39:38.839672+00
117	msgs	0088_broadcast_send_all	2017-07-27 20:39:38.965745+00
118	msgs	0089_populate_broadcast_send_all	2017-07-27 20:39:39.227034+00
119	msgs	0090_auto_20170407_2017	2017-07-27 20:39:39.356153+00
120	msgs	0091_exportmessagestask_system_label	2017-07-27 20:39:39.48535+00
121	msgs	0092_auto_20170428_1935	2017-07-27 20:39:39.733891+00
122	msgs	0093_populate_translatables	2017-07-27 20:39:39.744773+00
123	msgs	0094_auto_20170501_1641	2017-07-27 20:39:40.74225+00
124	public	0003_reset_1	2017-07-27 20:39:41.023735+00
125	public	0004_auto_20170228_0837	2017-07-27 20:39:41.644423+00
126	reports	0002_reset_1	2017-07-27 20:39:41.913413+00
127	reports	0003_auto_20170228_0837	2017-07-27 20:39:42.299828+00
128	schedules	0004_auto_20170228_0837	2017-07-27 20:39:42.54802+00
129	sessions	0001_initial	2017-07-27 20:39:42.571393+00
130	sites	0001_initial	2017-07-27 20:39:42.586791+00
131	sites	0002_alter_domain_unique	2017-07-27 20:39:42.606833+00
132	triggers	0006_reset_1	2017-07-27 20:39:42.819013+00
133	triggers	0007_auto_20170117_2130	2017-07-27 20:39:43.413531+00
134	triggers	0008_auto_20170228_0837	2017-07-27 20:39:43.800591+00
135	triggers	0009_auto_20170508_1636	2017-07-27 20:39:44.114166+00
136	triggers	0010_auto_20170509_1506	2017-07-27 20:39:44.248156+00
137	users	0001_initial	2017-07-27 20:39:44.803895+00
138	ussd	0002_reset_1	2017-07-27 20:39:44.815112+00
139	values	0008_reset_1	2017-07-27 20:39:45.000802+00
140	values	0009_install_indexes	2017-07-27 20:39:45.030244+00
141	values	0010_value_indexes	2017-07-27 20:39:45.090495+00
\.


--
-- Name: django_migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('django_migrations_id_seq', 141, true);


--
-- Data for Name: django_session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY django_session (session_key, session_data, expire_date) FROM stdin;
\.


--
-- Data for Name: django_site; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY django_site (id, domain, name) FROM stdin;
1	example.com	example.com
\.


--
-- Name: django_site_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('django_site_id_seq', 1, true);


--
-- Data for Name: flows_actionlog; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_actionlog (id, text, level, created_on, run_id) FROM stdin;
\.


--
-- Name: flows_actionlog_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_actionlog_id_seq', 1, false);


--
-- Data for Name: flows_actionset; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_actionset (id, uuid, destination, destination_type, actions, x, y, created_on, modified_on, flow_id) FROM stdin;
\.


--
-- Name: flows_actionset_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_actionset_id_seq', 1, false);


--
-- Data for Name: flows_exportflowresultstask; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_exportflowresultstask (id, is_active, created_on, modified_on, uuid, config, created_by_id, modified_by_id, org_id, status) FROM stdin;
\.


--
-- Data for Name: flows_exportflowresultstask_flows; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_exportflowresultstask_flows (id, exportflowresultstask_id, flow_id) FROM stdin;
\.


--
-- Name: flows_exportflowresultstask_flows_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_exportflowresultstask_flows_id_seq', 1, false);


--
-- Name: flows_exportflowresultstask_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_exportflowresultstask_id_seq', 1, false);


--
-- Data for Name: flows_flow; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flow (id, is_active, created_on, modified_on, uuid, name, entry_uuid, entry_type, is_archived, flow_type, metadata, expires_after_minutes, ignore_triggers, saved_on, base_language, version_number, created_by_id, modified_by_id, org_id, saved_by_id) FROM stdin;
\.


--
-- Name: flows_flow_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flow_id_seq', 1, false);


--
-- Data for Name: flows_flow_labels; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flow_labels (id, flow_id, flowlabel_id) FROM stdin;
\.


--
-- Name: flows_flow_labels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flow_labels_id_seq', 1, false);


--
-- Data for Name: flows_flowlabel; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowlabel (id, uuid, name, org_id, parent_id) FROM stdin;
\.


--
-- Name: flows_flowlabel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowlabel_id_seq', 1, false);


--
-- Data for Name: flows_flownodecount; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flownodecount (id, is_squashed, node_uuid, count, flow_id) FROM stdin;
\.


--
-- Name: flows_flownodecount_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flownodecount_id_seq', 1, false);


--
-- Data for Name: flows_flowpathcount; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowpathcount (id, from_uuid, to_uuid, period, count, flow_id, is_squashed) FROM stdin;
\.


--
-- Name: flows_flowpathcount_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowpathcount_id_seq', 1, false);


--
-- Data for Name: flows_flowpathrecentstep; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowpathrecentstep (id, from_uuid, to_uuid, left_on, step_id) FROM stdin;
\.


--
-- Name: flows_flowpathrecentstep_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowpathrecentstep_id_seq', 1, false);


--
-- Data for Name: flows_flowrevision; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowrevision (id, is_active, created_on, modified_on, definition, spec_version, revision, created_by_id, flow_id, modified_by_id) FROM stdin;
\.


--
-- Name: flows_flowrevision_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowrevision_id_seq', 1, false);


--
-- Data for Name: flows_flowrun; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowrun (id, is_active, fields, created_on, modified_on, exited_on, exit_type, expires_on, timeout_on, responded, contact_id, flow_id, org_id, parent_id, session_id, start_id, submitted_by_id) FROM stdin;
\.


--
-- Name: flows_flowrun_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowrun_id_seq', 1, false);


--
-- Data for Name: flows_flowruncount; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowruncount (id, exit_type, count, flow_id, is_squashed) FROM stdin;
\.


--
-- Name: flows_flowruncount_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowruncount_id_seq', 1, false);


--
-- Data for Name: flows_flowstart; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowstart (id, is_active, created_on, modified_on, restart_participants, contact_count, status, extra, created_by_id, flow_id, modified_by_id, include_active) FROM stdin;
\.


--
-- Data for Name: flows_flowstart_contacts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowstart_contacts (id, flowstart_id, contact_id) FROM stdin;
\.


--
-- Name: flows_flowstart_contacts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowstart_contacts_id_seq', 1, false);


--
-- Data for Name: flows_flowstart_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowstart_groups (id, flowstart_id, contactgroup_id) FROM stdin;
\.


--
-- Name: flows_flowstart_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowstart_groups_id_seq', 1, false);


--
-- Name: flows_flowstart_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowstart_id_seq', 1, false);


--
-- Data for Name: flows_flowstep; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowstep (id, step_type, step_uuid, rule_uuid, rule_category, rule_value, rule_decimal_value, next_uuid, arrived_on, left_on, contact_id, run_id) FROM stdin;
\.


--
-- Data for Name: flows_flowstep_broadcasts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowstep_broadcasts (id, flowstep_id, broadcast_id) FROM stdin;
\.


--
-- Name: flows_flowstep_broadcasts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowstep_broadcasts_id_seq', 1, false);


--
-- Name: flows_flowstep_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowstep_id_seq', 1, false);


--
-- Data for Name: flows_flowstep_messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_flowstep_messages (id, flowstep_id, msg_id) FROM stdin;
\.


--
-- Name: flows_flowstep_messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_flowstep_messages_id_seq', 1, false);


--
-- Data for Name: flows_ruleset; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY flows_ruleset (id, uuid, label, operand, webhook_url, webhook_action, rules, finished_key, value_type, ruleset_type, response_type, config, x, y, created_on, modified_on, flow_id) FROM stdin;
\.


--
-- Name: flows_ruleset_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('flows_ruleset_id_seq', 1, false);


--
-- Data for Name: guardian_groupobjectpermission; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY guardian_groupobjectpermission (id, object_pk, content_type_id, group_id, permission_id) FROM stdin;
\.


--
-- Name: guardian_groupobjectpermission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('guardian_groupobjectpermission_id_seq', 1, false);


--
-- Data for Name: guardian_userobjectpermission; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY guardian_userobjectpermission (id, object_pk, content_type_id, permission_id, user_id) FROM stdin;
\.


--
-- Name: guardian_userobjectpermission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('guardian_userobjectpermission_id_seq', 1, false);


--
-- Data for Name: locations_adminboundary; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY locations_adminboundary (id, osm_id, name, level, geometry, simplified_geometry, lft, rght, tree_id, parent_id) FROM stdin;
\.


--
-- Name: locations_adminboundary_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('locations_adminboundary_id_seq', 1, false);


--
-- Data for Name: locations_boundaryalias; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY locations_boundaryalias (id, is_active, created_on, modified_on, name, boundary_id, created_by_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: locations_boundaryalias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('locations_boundaryalias_id_seq', 1, false);


--
-- Data for Name: msgs_broadcast; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_broadcast (id, recipient_count, status, base_language, is_active, created_on, modified_on, purged, channel_id, created_by_id, modified_by_id, org_id, parent_id, schedule_id, send_all, media, text) FROM stdin;
\.


--
-- Data for Name: msgs_broadcast_contacts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_broadcast_contacts (id, broadcast_id, contact_id) FROM stdin;
\.


--
-- Name: msgs_broadcast_contacts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_broadcast_contacts_id_seq', 1, false);


--
-- Data for Name: msgs_broadcast_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_broadcast_groups (id, broadcast_id, contactgroup_id) FROM stdin;
\.


--
-- Name: msgs_broadcast_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_broadcast_groups_id_seq', 1, false);


--
-- Name: msgs_broadcast_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_broadcast_id_seq', 1, false);


--
-- Data for Name: msgs_broadcast_recipients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_broadcast_recipients (id, purged_status, broadcast_id, contact_id) FROM stdin;
\.


--
-- Name: msgs_broadcast_recipients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_broadcast_recipients_id_seq', 1, false);


--
-- Data for Name: msgs_broadcast_urns; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_broadcast_urns (id, broadcast_id, contacturn_id) FROM stdin;
\.


--
-- Name: msgs_broadcast_urns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_broadcast_urns_id_seq', 1, false);


--
-- Data for Name: msgs_exportmessagestask; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_exportmessagestask (id, is_active, created_on, modified_on, start_date, end_date, uuid, created_by_id, label_id, modified_by_id, org_id, status, system_label) FROM stdin;
\.


--
-- Data for Name: msgs_exportmessagestask_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_exportmessagestask_groups (id, exportmessagestask_id, contactgroup_id) FROM stdin;
\.


--
-- Name: msgs_exportmessagestask_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_exportmessagestask_groups_id_seq', 1, false);


--
-- Name: msgs_exportmessagestask_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_exportmessagestask_id_seq', 1, false);


--
-- Data for Name: msgs_label; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_label (id, is_active, created_on, modified_on, uuid, name, label_type, created_by_id, folder_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: msgs_label_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_label_id_seq', 1, false);


--
-- Data for Name: msgs_labelcount; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_labelcount (id, is_squashed, count, label_id) FROM stdin;
\.


--
-- Name: msgs_labelcount_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_labelcount_id_seq', 1, false);


--
-- Data for Name: msgs_msg; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_msg (id, text, priority, created_on, modified_on, sent_on, queued_on, direction, status, visibility, has_template_error, msg_type, msg_count, error_count, next_attempt, external_id, media, broadcast_id, channel_id, contact_id, contact_urn_id, org_id, response_to_id, topup_id, session_id) FROM stdin;
\.


--
-- Name: msgs_msg_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_msg_id_seq', 1, false);


--
-- Data for Name: msgs_msg_labels; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_msg_labels (id, msg_id, label_id) FROM stdin;
\.


--
-- Name: msgs_msg_labels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_msg_labels_id_seq', 1, false);


--
-- Name: msgs_systemlabel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('msgs_systemlabel_id_seq', 1, false);


--
-- Data for Name: msgs_systemlabelcount; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY msgs_systemlabelcount (id, label_type, count, org_id, is_squashed) FROM stdin;
\.


--
-- Data for Name: orgs_creditalert; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_creditalert (id, is_active, created_on, modified_on, alert_type, created_by_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: orgs_creditalert_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_creditalert_id_seq', 1, false);


--
-- Data for Name: orgs_debit; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_debit (id, amount, debit_type, created_on, beneficiary_id, created_by_id, topup_id, is_squashed) FROM stdin;
\.


--
-- Name: orgs_debit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_debit_id_seq', 1, false);


--
-- Data for Name: orgs_invitation; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_invitation (id, is_active, created_on, modified_on, email, secret, user_group, created_by_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: orgs_invitation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_invitation_id_seq', 1, false);


--
-- Data for Name: orgs_language; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_language (id, is_active, created_on, modified_on, name, iso_code, created_by_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: orgs_language_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_language_id_seq', 1, false);


--
-- Data for Name: orgs_org; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_org (id, is_active, created_on, modified_on, name, plan, plan_start, stripe_customer, language, timezone, date_format, webhook, webhook_events, msg_last_viewed, flows_last_viewed, config, slug, is_anon, is_purgeable, brand, surveyor_password, country_id, created_by_id, modified_by_id, parent_id, primary_language_id) FROM stdin;
\.


--
-- Data for Name: orgs_org_administrators; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_org_administrators (id, org_id, user_id) FROM stdin;
\.


--
-- Name: orgs_org_administrators_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_org_administrators_id_seq', 1, false);


--
-- Data for Name: orgs_org_editors; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_org_editors (id, org_id, user_id) FROM stdin;
\.


--
-- Name: orgs_org_editors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_org_editors_id_seq', 1, false);


--
-- Name: orgs_org_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_org_id_seq', 1, false);


--
-- Data for Name: orgs_org_surveyors; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_org_surveyors (id, org_id, user_id) FROM stdin;
\.


--
-- Name: orgs_org_surveyors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_org_surveyors_id_seq', 1, false);


--
-- Data for Name: orgs_org_viewers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_org_viewers (id, org_id, user_id) FROM stdin;
\.


--
-- Name: orgs_org_viewers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_org_viewers_id_seq', 1, false);


--
-- Data for Name: orgs_topup; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_topup (id, is_active, created_on, modified_on, price, credits, expires_on, stripe_charge, comment, created_by_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: orgs_topup_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_topup_id_seq', 1, false);


--
-- Data for Name: orgs_topupcredits; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_topupcredits (id, used, topup_id, is_squashed) FROM stdin;
\.


--
-- Name: orgs_topupcredits_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_topupcredits_id_seq', 1, false);


--
-- Data for Name: orgs_usersettings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs_usersettings (id, language, tel, user_id) FROM stdin;
\.


--
-- Name: orgs_usersettings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_usersettings_id_seq', 1, false);


--
-- Data for Name: public_lead; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public_lead (id, is_active, created_on, modified_on, email, created_by_id, modified_by_id) FROM stdin;
\.


--
-- Name: public_lead_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public_lead_id_seq', 1, false);


--
-- Data for Name: public_video; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public_video (id, is_active, created_on, modified_on, name, summary, description, vimeo_id, "order", created_by_id, modified_by_id) FROM stdin;
\.


--
-- Name: public_video_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public_video_id_seq', 1, false);


--
-- Data for Name: reports_report; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY reports_report (id, is_active, created_on, modified_on, title, description, config, is_published, created_by_id, modified_by_id, org_id) FROM stdin;
\.


--
-- Name: reports_report_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('reports_report_id_seq', 1, false);


--
-- Data for Name: schedules_schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY schedules_schedule (id, is_active, created_on, modified_on, status, repeat_hour_of_day, repeat_minute_of_hour, repeat_day_of_month, repeat_period, repeat_days, last_fire, next_fire, created_by_id, modified_by_id) FROM stdin;
\.


--
-- Name: schedules_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('schedules_schedule_id_seq', 1, false);


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: triggers_trigger; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY triggers_trigger (id, is_active, created_on, modified_on, keyword, last_triggered, trigger_count, is_archived, trigger_type, channel_id, created_by_id, flow_id, modified_by_id, org_id, schedule_id, referrer_id, match_type) FROM stdin;
\.


--
-- Data for Name: triggers_trigger_contacts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY triggers_trigger_contacts (id, trigger_id, contact_id) FROM stdin;
\.


--
-- Name: triggers_trigger_contacts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('triggers_trigger_contacts_id_seq', 1, false);


--
-- Data for Name: triggers_trigger_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY triggers_trigger_groups (id, trigger_id, contactgroup_id) FROM stdin;
\.


--
-- Name: triggers_trigger_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('triggers_trigger_groups_id_seq', 1, false);


--
-- Name: triggers_trigger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('triggers_trigger_id_seq', 1, false);


--
-- Data for Name: users_failedlogin; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY users_failedlogin (id, failed_on, user_id) FROM stdin;
\.


--
-- Name: users_failedlogin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('users_failedlogin_id_seq', 1, false);


--
-- Data for Name: users_passwordhistory; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY users_passwordhistory (id, password, set_on, user_id) FROM stdin;
\.


--
-- Name: users_passwordhistory_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('users_passwordhistory_id_seq', 1, false);


--
-- Data for Name: users_recoverytoken; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY users_recoverytoken (id, token, created_on, user_id) FROM stdin;
\.


--
-- Name: users_recoverytoken_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('users_recoverytoken_id_seq', 1, false);


--
-- Data for Name: values_value; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY values_value (id, rule_uuid, category, string_value, decimal_value, datetime_value, media_value, created_on, modified_on, contact_id, contact_field_id, location_value_id, org_id, ruleset_id, run_id) FROM stdin;
\.


--
-- Name: values_value_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('values_value_id_seq', 1, false);


SET search_path = tiger, pg_catalog;

--
-- Data for Name: geocode_settings; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY geocode_settings (name, setting, unit, category, short_desc) FROM stdin;
\.


--
-- Data for Name: pagc_gaz; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY pagc_gaz (id, seq, word, stdword, token, is_custom) FROM stdin;
\.


--
-- Data for Name: pagc_lex; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY pagc_lex (id, seq, word, stdword, token, is_custom) FROM stdin;
\.


--
-- Data for Name: pagc_rules; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY pagc_rules (id, rule, is_custom) FROM stdin;
\.


SET search_path = topology, pg_catalog;

--
-- Data for Name: topology; Type: TABLE DATA; Schema: topology; Owner: postgres
--

COPY topology (id, name, srid, "precision", hasz) FROM stdin;
\.


--
-- Data for Name: layer; Type: TABLE DATA; Schema: topology; Owner: postgres
--

COPY layer (topology_id, layer_id, schema_name, table_name, feature_column, feature_type, level, child_id) FROM stdin;
\.


SET search_path = public, pg_catalog;

--
-- Name: airtime_airtimetransfer airtime_airtimetransfer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY airtime_airtimetransfer
    ADD CONSTRAINT airtime_airtimetransfer_pkey PRIMARY KEY (id);


--
-- Name: api_apitoken api_apitoken_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_apitoken
    ADD CONSTRAINT api_apitoken_pkey PRIMARY KEY (key);


--
-- Name: api_resthook api_resthook_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_resthook
    ADD CONSTRAINT api_resthook_pkey PRIMARY KEY (id);


--
-- Name: api_resthooksubscriber api_resthooksubscriber_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_resthooksubscriber
    ADD CONSTRAINT api_resthooksubscriber_pkey PRIMARY KEY (id);


--
-- Name: api_webhookevent api_webhookevent_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookevent
    ADD CONSTRAINT api_webhookevent_pkey PRIMARY KEY (id);


--
-- Name: api_webhookresult api_webhookresult_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookresult
    ADD CONSTRAINT api_webhookresult_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions auth_group_permissions_group_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_permission auth_permission_content_type_id_01ab375a_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_user_id_94350c0c_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_94350c0c_uniq UNIQUE (user_id, group_id);


--
-- Name: auth_user auth_user_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user
    ADD CONSTRAINT auth_user_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_14a6b632_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_14a6b632_uniq UNIQUE (user_id, permission_id);


--
-- Name: auth_user auth_user_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user
    ADD CONSTRAINT auth_user_username_key UNIQUE (username);


--
-- Name: authtoken_token authtoken_token_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY authtoken_token
    ADD CONSTRAINT authtoken_token_pkey PRIMARY KEY (key);


--
-- Name: authtoken_token authtoken_token_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY authtoken_token
    ADD CONSTRAINT authtoken_token_user_id_key UNIQUE (user_id);


--
-- Name: campaigns_campaign campaigns_campaign_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaign
    ADD CONSTRAINT campaigns_campaign_pkey PRIMARY KEY (id);


--
-- Name: campaigns_campaign campaigns_campaign_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaign
    ADD CONSTRAINT campaigns_campaign_uuid_key UNIQUE (uuid);


--
-- Name: campaigns_campaignevent campaigns_campaignevent_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaignevent
    ADD CONSTRAINT campaigns_campaignevent_pkey PRIMARY KEY (id);


--
-- Name: campaigns_campaignevent campaigns_campaignevent_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaignevent
    ADD CONSTRAINT campaigns_campaignevent_uuid_key UNIQUE (uuid);


--
-- Name: campaigns_eventfire campaigns_eventfire_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_eventfire
    ADD CONSTRAINT campaigns_eventfire_pkey PRIMARY KEY (id);


--
-- Name: channels_alert channels_alert_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_alert
    ADD CONSTRAINT channels_alert_pkey PRIMARY KEY (id);


--
-- Name: channels_channel channels_channel_claim_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channel
    ADD CONSTRAINT channels_channel_claim_code_key UNIQUE (claim_code);


--
-- Name: channels_channel channels_channel_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channel
    ADD CONSTRAINT channels_channel_pkey PRIMARY KEY (id);


--
-- Name: channels_channel channels_channel_secret_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channel
    ADD CONSTRAINT channels_channel_secret_key UNIQUE (secret);


--
-- Name: channels_channel channels_channel_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channel
    ADD CONSTRAINT channels_channel_uuid_key UNIQUE (uuid);


--
-- Name: channels_channelcount channels_channelcount_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelcount
    ADD CONSTRAINT channels_channelcount_pkey PRIMARY KEY (id);


--
-- Name: channels_channelevent channels_channelevent_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelevent
    ADD CONSTRAINT channels_channelevent_pkey PRIMARY KEY (id);


--
-- Name: channels_channellog channels_channellog_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channellog
    ADD CONSTRAINT channels_channellog_pkey PRIMARY KEY (id);


--
-- Name: channels_channelsession channels_channelsession_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelsession
    ADD CONSTRAINT channels_channelsession_pkey PRIMARY KEY (id);


--
-- Name: channels_syncevent channels_syncevent_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_syncevent
    ADD CONSTRAINT channels_syncevent_pkey PRIMARY KEY (id);


--
-- Name: contacts_contact contacts_contact_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contact
    ADD CONSTRAINT contacts_contact_pkey PRIMARY KEY (id);


--
-- Name: contacts_contact contacts_contact_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contact
    ADD CONSTRAINT contacts_contact_uuid_key UNIQUE (uuid);


--
-- Name: contacts_contactfield contacts_contactfield_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactfield
    ADD CONSTRAINT contacts_contactfield_pkey PRIMARY KEY (id);


--
-- Name: contacts_contactgroup_contacts contacts_contactgroup_contacts_contactgroup_id_0f909f73_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup_contacts
    ADD CONSTRAINT contacts_contactgroup_contacts_contactgroup_id_0f909f73_uniq UNIQUE (contactgroup_id, contact_id);


--
-- Name: contacts_contactgroup_contacts contacts_contactgroup_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup_contacts
    ADD CONSTRAINT contacts_contactgroup_contacts_pkey PRIMARY KEY (id);


--
-- Name: contacts_contactgroup contacts_contactgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup
    ADD CONSTRAINT contacts_contactgroup_pkey PRIMARY KEY (id);


--
-- Name: contacts_contactgroup_query_fields contacts_contactgroup_query_field_contactgroup_id_642b9244_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup_query_fields
    ADD CONSTRAINT contacts_contactgroup_query_field_contactgroup_id_642b9244_uniq UNIQUE (contactgroup_id, contactfield_id);


--
-- Name: contacts_contactgroup_query_fields contacts_contactgroup_query_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup_query_fields
    ADD CONSTRAINT contacts_contactgroup_query_fields_pkey PRIMARY KEY (id);


--
-- Name: contacts_contactgroup contacts_contactgroup_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup
    ADD CONSTRAINT contacts_contactgroup_uuid_key UNIQUE (uuid);


--
-- Name: contacts_contactgroupcount contacts_contactgroupcount_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroupcount
    ADD CONSTRAINT contacts_contactgroupcount_pkey PRIMARY KEY (id);


--
-- Name: contacts_contacturn contacts_contacturn_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contacturn
    ADD CONSTRAINT contacts_contacturn_pkey PRIMARY KEY (id);


--
-- Name: contacts_contacturn contacts_contacturn_urn_a86b9105_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contacturn
    ADD CONSTRAINT contacts_contacturn_urn_a86b9105_uniq UNIQUE (urn, org_id);


--
-- Name: contacts_exportcontactstask contacts_exportcontactstask_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_exportcontactstask
    ADD CONSTRAINT contacts_exportcontactstask_pkey PRIMARY KEY (id);


--
-- Name: contacts_exportcontactstask contacts_exportcontactstask_uuid_aad904fe_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_exportcontactstask
    ADD CONSTRAINT contacts_exportcontactstask_uuid_aad904fe_uniq UNIQUE (uuid);


--
-- Name: csv_imports_importtask csv_imports_importtask_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY csv_imports_importtask
    ADD CONSTRAINT csv_imports_importtask_pkey PRIMARY KEY (id);


--
-- Name: django_content_type django_content_type_app_label_76bd3d3b_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_content_type
    ADD CONSTRAINT django_content_type_app_label_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- Name: django_site django_site_domain_a2e37b91_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_site
    ADD CONSTRAINT django_site_domain_a2e37b91_uniq UNIQUE (domain);


--
-- Name: django_site django_site_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_site
    ADD CONSTRAINT django_site_pkey PRIMARY KEY (id);


--
-- Name: flows_actionlog flows_actionlog_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_actionlog
    ADD CONSTRAINT flows_actionlog_pkey PRIMARY KEY (id);


--
-- Name: flows_actionset flows_actionset_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_actionset
    ADD CONSTRAINT flows_actionset_pkey PRIMARY KEY (id);


--
-- Name: flows_actionset flows_actionset_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_actionset
    ADD CONSTRAINT flows_actionset_uuid_key UNIQUE (uuid);


--
-- Name: flows_exportflowresultstask_flows flows_exportflowresultst_exportflowresultstask_id_4e70a5c5_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_exportflowresultstask_flows
    ADD CONSTRAINT flows_exportflowresultst_exportflowresultstask_id_4e70a5c5_uniq UNIQUE (exportflowresultstask_id, flow_id);


--
-- Name: flows_exportflowresultstask_flows flows_exportflowresultstask_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_exportflowresultstask_flows
    ADD CONSTRAINT flows_exportflowresultstask_flows_pkey PRIMARY KEY (id);


--
-- Name: flows_exportflowresultstask flows_exportflowresultstask_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_exportflowresultstask
    ADD CONSTRAINT flows_exportflowresultstask_pkey PRIMARY KEY (id);


--
-- Name: flows_exportflowresultstask flows_exportflowresultstask_uuid_ed7e2021_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_exportflowresultstask
    ADD CONSTRAINT flows_exportflowresultstask_uuid_ed7e2021_uniq UNIQUE (uuid);


--
-- Name: flows_flow flows_flow_entry_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow
    ADD CONSTRAINT flows_flow_entry_uuid_key UNIQUE (entry_uuid);


--
-- Name: flows_flow_labels flows_flow_labels_flow_id_99ec8abf_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow_labels
    ADD CONSTRAINT flows_flow_labels_flow_id_99ec8abf_uniq UNIQUE (flow_id, flowlabel_id);


--
-- Name: flows_flow_labels flows_flow_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow_labels
    ADD CONSTRAINT flows_flow_labels_pkey PRIMARY KEY (id);


--
-- Name: flows_flow flows_flow_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow
    ADD CONSTRAINT flows_flow_pkey PRIMARY KEY (id);


--
-- Name: flows_flow flows_flow_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow
    ADD CONSTRAINT flows_flow_uuid_key UNIQUE (uuid);


--
-- Name: flows_flowlabel flows_flowlabel_name_00066d3a_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowlabel
    ADD CONSTRAINT flows_flowlabel_name_00066d3a_uniq UNIQUE (name, parent_id, org_id);


--
-- Name: flows_flowlabel flows_flowlabel_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowlabel
    ADD CONSTRAINT flows_flowlabel_pkey PRIMARY KEY (id);


--
-- Name: flows_flowlabel flows_flowlabel_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowlabel
    ADD CONSTRAINT flows_flowlabel_uuid_key UNIQUE (uuid);


--
-- Name: flows_flownodecount flows_flownodecount_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flownodecount
    ADD CONSTRAINT flows_flownodecount_pkey PRIMARY KEY (id);


--
-- Name: flows_flowpathcount flows_flowpathcount_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowpathcount
    ADD CONSTRAINT flows_flowpathcount_pkey PRIMARY KEY (id);


--
-- Name: flows_flowpathrecentstep flows_flowpathrecentstep_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowpathrecentstep
    ADD CONSTRAINT flows_flowpathrecentstep_pkey PRIMARY KEY (id);


--
-- Name: flows_flowrevision flows_flowrevision_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrevision
    ADD CONSTRAINT flows_flowrevision_pkey PRIMARY KEY (id);


--
-- Name: flows_flowrun flows_flowrun_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrun
    ADD CONSTRAINT flows_flowrun_pkey PRIMARY KEY (id);


--
-- Name: flows_flowruncount flows_flowruncount_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowruncount
    ADD CONSTRAINT flows_flowruncount_pkey PRIMARY KEY (id);


--
-- Name: flows_flowstart_contacts flows_flowstart_contacts_flowstart_id_88b65412_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart_contacts
    ADD CONSTRAINT flows_flowstart_contacts_flowstart_id_88b65412_uniq UNIQUE (flowstart_id, contact_id);


--
-- Name: flows_flowstart_contacts flows_flowstart_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart_contacts
    ADD CONSTRAINT flows_flowstart_contacts_pkey PRIMARY KEY (id);


--
-- Name: flows_flowstart_groups flows_flowstart_groups_flowstart_id_fc0b5f4f_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart_groups
    ADD CONSTRAINT flows_flowstart_groups_flowstart_id_fc0b5f4f_uniq UNIQUE (flowstart_id, contactgroup_id);


--
-- Name: flows_flowstart_groups flows_flowstart_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart_groups
    ADD CONSTRAINT flows_flowstart_groups_pkey PRIMARY KEY (id);


--
-- Name: flows_flowstart flows_flowstart_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart
    ADD CONSTRAINT flows_flowstart_pkey PRIMARY KEY (id);


--
-- Name: flows_flowstep_broadcasts flows_flowstep_broadcasts_flowstep_id_c9cb8603_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep_broadcasts
    ADD CONSTRAINT flows_flowstep_broadcasts_flowstep_id_c9cb8603_uniq UNIQUE (flowstep_id, broadcast_id);


--
-- Name: flows_flowstep_broadcasts flows_flowstep_broadcasts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep_broadcasts
    ADD CONSTRAINT flows_flowstep_broadcasts_pkey PRIMARY KEY (id);


--
-- Name: flows_flowstep_messages flows_flowstep_messages_flowstep_id_3ce4a034_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep_messages
    ADD CONSTRAINT flows_flowstep_messages_flowstep_id_3ce4a034_uniq UNIQUE (flowstep_id, msg_id);


--
-- Name: flows_flowstep_messages flows_flowstep_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep_messages
    ADD CONSTRAINT flows_flowstep_messages_pkey PRIMARY KEY (id);


--
-- Name: flows_flowstep flows_flowstep_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep
    ADD CONSTRAINT flows_flowstep_pkey PRIMARY KEY (id);


--
-- Name: flows_ruleset flows_ruleset_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_ruleset
    ADD CONSTRAINT flows_ruleset_pkey PRIMARY KEY (id);


--
-- Name: flows_ruleset flows_ruleset_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_ruleset
    ADD CONSTRAINT flows_ruleset_uuid_key UNIQUE (uuid);


--
-- Name: guardian_groupobjectpermission guardian_groupobjectpermission_group_id_3f189f7c_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_groupobjectpermission
    ADD CONSTRAINT guardian_groupobjectpermission_group_id_3f189f7c_uniq UNIQUE (group_id, permission_id, object_pk);


--
-- Name: guardian_groupobjectpermission guardian_groupobjectpermission_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_groupobjectpermission
    ADD CONSTRAINT guardian_groupobjectpermission_pkey PRIMARY KEY (id);


--
-- Name: guardian_userobjectpermission guardian_userobjectpermission_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_userobjectpermission
    ADD CONSTRAINT guardian_userobjectpermission_pkey PRIMARY KEY (id);


--
-- Name: guardian_userobjectpermission guardian_userobjectpermission_user_id_b0b3d2fc_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_userobjectpermission
    ADD CONSTRAINT guardian_userobjectpermission_user_id_b0b3d2fc_uniq UNIQUE (user_id, permission_id, object_pk);


--
-- Name: locations_adminboundary locations_adminboundary_osm_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations_adminboundary
    ADD CONSTRAINT locations_adminboundary_osm_id_key UNIQUE (osm_id);


--
-- Name: locations_adminboundary locations_adminboundary_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations_adminboundary
    ADD CONSTRAINT locations_adminboundary_pkey PRIMARY KEY (id);


--
-- Name: locations_boundaryalias locations_boundaryalias_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations_boundaryalias
    ADD CONSTRAINT locations_boundaryalias_pkey PRIMARY KEY (id);


--
-- Name: msgs_broadcast_contacts msgs_broadcast_contacts_broadcast_id_85ec2380_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_contacts
    ADD CONSTRAINT msgs_broadcast_contacts_broadcast_id_85ec2380_uniq UNIQUE (broadcast_id, contact_id);


--
-- Name: msgs_broadcast_contacts msgs_broadcast_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_contacts
    ADD CONSTRAINT msgs_broadcast_contacts_pkey PRIMARY KEY (id);


--
-- Name: msgs_broadcast_groups msgs_broadcast_groups_broadcast_id_bc725cf0_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_groups
    ADD CONSTRAINT msgs_broadcast_groups_broadcast_id_bc725cf0_uniq UNIQUE (broadcast_id, contactgroup_id);


--
-- Name: msgs_broadcast_groups msgs_broadcast_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_groups
    ADD CONSTRAINT msgs_broadcast_groups_pkey PRIMARY KEY (id);


--
-- Name: msgs_broadcast msgs_broadcast_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast
    ADD CONSTRAINT msgs_broadcast_pkey PRIMARY KEY (id);


--
-- Name: msgs_broadcast_recipients msgs_broadcast_recipients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_recipients
    ADD CONSTRAINT msgs_broadcast_recipients_pkey PRIMARY KEY (id);


--
-- Name: msgs_broadcast msgs_broadcast_schedule_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast
    ADD CONSTRAINT msgs_broadcast_schedule_id_key UNIQUE (schedule_id);


--
-- Name: msgs_broadcast_urns msgs_broadcast_urns_broadcast_id_5fe7764f_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_urns
    ADD CONSTRAINT msgs_broadcast_urns_broadcast_id_5fe7764f_uniq UNIQUE (broadcast_id, contacturn_id);


--
-- Name: msgs_broadcast_urns msgs_broadcast_urns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_urns
    ADD CONSTRAINT msgs_broadcast_urns_pkey PRIMARY KEY (id);


--
-- Name: msgs_exportmessagestask_groups msgs_exportmessagestask_gro_exportmessagestask_id_d2d2009a_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask_groups
    ADD CONSTRAINT msgs_exportmessagestask_gro_exportmessagestask_id_d2d2009a_uniq UNIQUE (exportmessagestask_id, contactgroup_id);


--
-- Name: msgs_exportmessagestask_groups msgs_exportmessagestask_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask_groups
    ADD CONSTRAINT msgs_exportmessagestask_groups_pkey PRIMARY KEY (id);


--
-- Name: msgs_exportmessagestask msgs_exportmessagestask_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask
    ADD CONSTRAINT msgs_exportmessagestask_pkey PRIMARY KEY (id);


--
-- Name: msgs_exportmessagestask msgs_exportmessagestask_uuid_a9d02f48_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask
    ADD CONSTRAINT msgs_exportmessagestask_uuid_a9d02f48_uniq UNIQUE (uuid);


--
-- Name: msgs_label msgs_label_org_id_e4186cef_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_label
    ADD CONSTRAINT msgs_label_org_id_e4186cef_uniq UNIQUE (org_id, name);


--
-- Name: msgs_label msgs_label_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_label
    ADD CONSTRAINT msgs_label_pkey PRIMARY KEY (id);


--
-- Name: msgs_label msgs_label_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_label
    ADD CONSTRAINT msgs_label_uuid_key UNIQUE (uuid);


--
-- Name: msgs_labelcount msgs_labelcount_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_labelcount
    ADD CONSTRAINT msgs_labelcount_pkey PRIMARY KEY (id);


--
-- Name: msgs_msg_labels msgs_msg_labels_msg_id_98060205_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg_labels
    ADD CONSTRAINT msgs_msg_labels_msg_id_98060205_uniq UNIQUE (msg_id, label_id);


--
-- Name: msgs_msg_labels msgs_msg_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg_labels
    ADD CONSTRAINT msgs_msg_labels_pkey PRIMARY KEY (id);


--
-- Name: msgs_msg msgs_msg_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg
    ADD CONSTRAINT msgs_msg_pkey PRIMARY KEY (id);


--
-- Name: msgs_systemlabelcount msgs_systemlabel_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_systemlabelcount
    ADD CONSTRAINT msgs_systemlabel_pkey PRIMARY KEY (id);


--
-- Name: orgs_creditalert orgs_creditalert_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_creditalert
    ADD CONSTRAINT orgs_creditalert_pkey PRIMARY KEY (id);


--
-- Name: orgs_debit orgs_debit_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_debit
    ADD CONSTRAINT orgs_debit_pkey PRIMARY KEY (id);


--
-- Name: orgs_invitation orgs_invitation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_invitation
    ADD CONSTRAINT orgs_invitation_pkey PRIMARY KEY (id);


--
-- Name: orgs_invitation orgs_invitation_secret_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_invitation
    ADD CONSTRAINT orgs_invitation_secret_key UNIQUE (secret);


--
-- Name: orgs_language orgs_language_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_language
    ADD CONSTRAINT orgs_language_pkey PRIMARY KEY (id);


--
-- Name: orgs_org_administrators orgs_org_administrators_org_id_c6cb5bee_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_administrators
    ADD CONSTRAINT orgs_org_administrators_org_id_c6cb5bee_uniq UNIQUE (org_id, user_id);


--
-- Name: orgs_org_administrators orgs_org_administrators_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_administrators
    ADD CONSTRAINT orgs_org_administrators_pkey PRIMARY KEY (id);


--
-- Name: orgs_org_editors orgs_org_editors_org_id_635dc129_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_editors
    ADD CONSTRAINT orgs_org_editors_org_id_635dc129_uniq UNIQUE (org_id, user_id);


--
-- Name: orgs_org_editors orgs_org_editors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_editors
    ADD CONSTRAINT orgs_org_editors_pkey PRIMARY KEY (id);


--
-- Name: orgs_org orgs_org_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org
    ADD CONSTRAINT orgs_org_pkey PRIMARY KEY (id);


--
-- Name: orgs_org orgs_org_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org
    ADD CONSTRAINT orgs_org_slug_key UNIQUE (slug);


--
-- Name: orgs_org_surveyors orgs_org_surveyors_org_id_f78ff12f_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_surveyors
    ADD CONSTRAINT orgs_org_surveyors_org_id_f78ff12f_uniq UNIQUE (org_id, user_id);


--
-- Name: orgs_org_surveyors orgs_org_surveyors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_surveyors
    ADD CONSTRAINT orgs_org_surveyors_pkey PRIMARY KEY (id);


--
-- Name: orgs_org_viewers orgs_org_viewers_org_id_451e0d91_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_viewers
    ADD CONSTRAINT orgs_org_viewers_org_id_451e0d91_uniq UNIQUE (org_id, user_id);


--
-- Name: orgs_org_viewers orgs_org_viewers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_viewers
    ADD CONSTRAINT orgs_org_viewers_pkey PRIMARY KEY (id);


--
-- Name: orgs_topup orgs_topup_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_topup
    ADD CONSTRAINT orgs_topup_pkey PRIMARY KEY (id);


--
-- Name: orgs_topupcredits orgs_topupcredits_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_topupcredits
    ADD CONSTRAINT orgs_topupcredits_pkey PRIMARY KEY (id);


--
-- Name: orgs_usersettings orgs_usersettings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_usersettings
    ADD CONSTRAINT orgs_usersettings_pkey PRIMARY KEY (id);


--
-- Name: public_lead public_lead_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public_lead
    ADD CONSTRAINT public_lead_pkey PRIMARY KEY (id);


--
-- Name: public_video public_video_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public_video
    ADD CONSTRAINT public_video_pkey PRIMARY KEY (id);


--
-- Name: reports_report reports_report_org_id_d8b6ac42_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reports_report
    ADD CONSTRAINT reports_report_org_id_d8b6ac42_uniq UNIQUE (org_id, title);


--
-- Name: reports_report reports_report_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reports_report
    ADD CONSTRAINT reports_report_pkey PRIMARY KEY (id);


--
-- Name: schedules_schedule schedules_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY schedules_schedule
    ADD CONSTRAINT schedules_schedule_pkey PRIMARY KEY (id);


--
-- Name: triggers_trigger_contacts triggers_trigger_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger_contacts
    ADD CONSTRAINT triggers_trigger_contacts_pkey PRIMARY KEY (id);


--
-- Name: triggers_trigger_contacts triggers_trigger_contacts_trigger_id_a5309237_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger_contacts
    ADD CONSTRAINT triggers_trigger_contacts_trigger_id_a5309237_uniq UNIQUE (trigger_id, contact_id);


--
-- Name: triggers_trigger_groups triggers_trigger_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger_groups
    ADD CONSTRAINT triggers_trigger_groups_pkey PRIMARY KEY (id);


--
-- Name: triggers_trigger_groups triggers_trigger_groups_trigger_id_cf0ee28d_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger_groups
    ADD CONSTRAINT triggers_trigger_groups_trigger_id_cf0ee28d_uniq UNIQUE (trigger_id, contactgroup_id);


--
-- Name: triggers_trigger triggers_trigger_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger
    ADD CONSTRAINT triggers_trigger_pkey PRIMARY KEY (id);


--
-- Name: triggers_trigger triggers_trigger_schedule_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger
    ADD CONSTRAINT triggers_trigger_schedule_id_key UNIQUE (schedule_id);


--
-- Name: users_failedlogin users_failedlogin_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users_failedlogin
    ADD CONSTRAINT users_failedlogin_pkey PRIMARY KEY (id);


--
-- Name: users_passwordhistory users_passwordhistory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users_passwordhistory
    ADD CONSTRAINT users_passwordhistory_pkey PRIMARY KEY (id);


--
-- Name: users_recoverytoken users_recoverytoken_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users_recoverytoken
    ADD CONSTRAINT users_recoverytoken_pkey PRIMARY KEY (id);


--
-- Name: users_recoverytoken users_recoverytoken_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users_recoverytoken
    ADD CONSTRAINT users_recoverytoken_token_key UNIQUE (token);


--
-- Name: values_value values_value_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY values_value
    ADD CONSTRAINT values_value_pkey PRIMARY KEY (id);


--
-- Name: airtime_airtimetransfer_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX airtime_airtimetransfer_6d82f13d ON airtime_airtimetransfer USING btree (contact_id);


--
-- Name: airtime_airtimetransfer_72eb6c85; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX airtime_airtimetransfer_72eb6c85 ON airtime_airtimetransfer USING btree (channel_id);


--
-- Name: airtime_airtimetransfer_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX airtime_airtimetransfer_9cf869aa ON airtime_airtimetransfer USING btree (org_id);


--
-- Name: airtime_airtimetransfer_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX airtime_airtimetransfer_b3da0983 ON airtime_airtimetransfer USING btree (modified_by_id);


--
-- Name: airtime_airtimetransfer_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX airtime_airtimetransfer_e93cb7eb ON airtime_airtimetransfer USING btree (created_by_id);


--
-- Name: api_apitoken_84566833; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_apitoken_84566833 ON api_apitoken USING btree (role_id);


--
-- Name: api_apitoken_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_apitoken_9cf869aa ON api_apitoken USING btree (org_id);


--
-- Name: api_apitoken_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_apitoken_e8701ad4 ON api_apitoken USING btree (user_id);


--
-- Name: api_apitoken_key_e6fcf24a_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_apitoken_key_e6fcf24a_like ON api_apitoken USING btree (key varchar_pattern_ops);


--
-- Name: api_resthook_2dbcba41; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_resthook_2dbcba41 ON api_resthook USING btree (slug);


--
-- Name: api_resthook_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_resthook_9cf869aa ON api_resthook USING btree (org_id);


--
-- Name: api_resthook_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_resthook_b3da0983 ON api_resthook USING btree (modified_by_id);


--
-- Name: api_resthook_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_resthook_e93cb7eb ON api_resthook USING btree (created_by_id);


--
-- Name: api_resthook_slug_19d1d7bf_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_resthook_slug_19d1d7bf_like ON api_resthook USING btree (slug varchar_pattern_ops);


--
-- Name: api_resthooksubscriber_1bce5203; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_resthooksubscriber_1bce5203 ON api_resthooksubscriber USING btree (resthook_id);


--
-- Name: api_resthooksubscriber_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_resthooksubscriber_b3da0983 ON api_resthooksubscriber USING btree (modified_by_id);


--
-- Name: api_resthooksubscriber_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_resthooksubscriber_e93cb7eb ON api_resthooksubscriber USING btree (created_by_id);


--
-- Name: api_webhookevent_0acf093b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_webhookevent_0acf093b ON api_webhookevent USING btree (run_id);


--
-- Name: api_webhookevent_1bce5203; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_webhookevent_1bce5203 ON api_webhookevent USING btree (resthook_id);


--
-- Name: api_webhookevent_72eb6c85; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_webhookevent_72eb6c85 ON api_webhookevent USING btree (channel_id);


--
-- Name: api_webhookevent_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_webhookevent_9cf869aa ON api_webhookevent USING btree (org_id);


--
-- Name: api_webhookevent_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_webhookevent_b3da0983 ON api_webhookevent USING btree (modified_by_id);


--
-- Name: api_webhookevent_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_webhookevent_e93cb7eb ON api_webhookevent USING btree (created_by_id);


--
-- Name: api_webhookresult_4437cfac; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_webhookresult_4437cfac ON api_webhookresult USING btree (event_id);


--
-- Name: api_webhookresult_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_webhookresult_b3da0983 ON api_webhookresult USING btree (modified_by_id);


--
-- Name: api_webhookresult_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_webhookresult_e93cb7eb ON api_webhookresult USING btree (created_by_id);


--
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_name_a6ea08ec_like ON auth_group USING btree (name varchar_pattern_ops);


--
-- Name: auth_group_permissions_0e939a4f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_permissions_0e939a4f ON auth_group_permissions USING btree (group_id);


--
-- Name: auth_group_permissions_8373b171; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_permissions_8373b171 ON auth_group_permissions USING btree (permission_id);


--
-- Name: auth_permission_417f1b1c; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_permission_417f1b1c ON auth_permission USING btree (content_type_id);


--
-- Name: auth_user_groups_0e939a4f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_groups_0e939a4f ON auth_user_groups USING btree (group_id);


--
-- Name: auth_user_groups_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_groups_e8701ad4 ON auth_user_groups USING btree (user_id);


--
-- Name: auth_user_user_permissions_8373b171; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_user_permissions_8373b171 ON auth_user_user_permissions USING btree (permission_id);


--
-- Name: auth_user_user_permissions_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_user_permissions_e8701ad4 ON auth_user_user_permissions USING btree (user_id);


--
-- Name: auth_user_username_6821ab7c_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_username_6821ab7c_like ON auth_user USING btree (username varchar_pattern_ops);


--
-- Name: authtoken_token_key_10f0b77e_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX authtoken_token_key_10f0b77e_like ON authtoken_token USING btree (key varchar_pattern_ops);


--
-- Name: campaigns_campaign_0e939a4f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_campaign_0e939a4f ON campaigns_campaign USING btree (group_id);


--
-- Name: campaigns_campaign_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_campaign_9cf869aa ON campaigns_campaign USING btree (org_id);


--
-- Name: campaigns_campaign_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_campaign_b3da0983 ON campaigns_campaign USING btree (modified_by_id);


--
-- Name: campaigns_campaign_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_campaign_e93cb7eb ON campaigns_campaign USING btree (created_by_id);


--
-- Name: campaigns_campaign_uuid_ff86cf7f_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_campaign_uuid_ff86cf7f_like ON campaigns_campaign USING btree (uuid varchar_pattern_ops);


--
-- Name: campaigns_campaignevent_61d66954; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_campaignevent_61d66954 ON campaigns_campaignevent USING btree (relative_to_id);


--
-- Name: campaigns_campaignevent_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_campaignevent_7f26ac5b ON campaigns_campaignevent USING btree (flow_id);


--
-- Name: campaigns_campaignevent_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_campaignevent_b3da0983 ON campaigns_campaignevent USING btree (modified_by_id);


--
-- Name: campaigns_campaignevent_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_campaignevent_e93cb7eb ON campaigns_campaignevent USING btree (created_by_id);


--
-- Name: campaigns_campaignevent_f14acec3; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_campaignevent_f14acec3 ON campaigns_campaignevent USING btree (campaign_id);


--
-- Name: campaigns_campaignevent_uuid_6f074205_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_campaignevent_uuid_6f074205_like ON campaigns_campaignevent USING btree (uuid varchar_pattern_ops);


--
-- Name: campaigns_eventfire_4437cfac; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_eventfire_4437cfac ON campaigns_eventfire USING btree (event_id);


--
-- Name: campaigns_eventfire_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX campaigns_eventfire_6d82f13d ON campaigns_eventfire USING btree (contact_id);


--
-- Name: channels_alert_72eb6c85; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_alert_72eb6c85 ON channels_alert USING btree (channel_id);


--
-- Name: channels_alert_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_alert_b3da0983 ON channels_alert USING btree (modified_by_id);


--
-- Name: channels_alert_c8730bec; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_alert_c8730bec ON channels_alert USING btree (sync_event_id);


--
-- Name: channels_alert_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_alert_e93cb7eb ON channels_alert USING btree (created_by_id);


--
-- Name: channels_channel_6be37982; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channel_6be37982 ON channels_channel USING btree (parent_id);


--
-- Name: channels_channel_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channel_9cf869aa ON channels_channel USING btree (org_id);


--
-- Name: channels_channel_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channel_b3da0983 ON channels_channel USING btree (modified_by_id);


--
-- Name: channels_channel_claim_code_13b82678_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channel_claim_code_13b82678_like ON channels_channel USING btree (claim_code varchar_pattern_ops);


--
-- Name: channels_channel_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channel_e93cb7eb ON channels_channel USING btree (created_by_id);


--
-- Name: channels_channel_secret_7f9a562d_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channel_secret_7f9a562d_like ON channels_channel USING btree (secret varchar_pattern_ops);


--
-- Name: channels_channel_uuid_6008b898_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channel_uuid_6008b898_like ON channels_channel USING btree (uuid varchar_pattern_ops);


--
-- Name: channels_channelcount_72eb6c85; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelcount_72eb6c85 ON channels_channelcount USING btree (channel_id);


--
-- Name: channels_channelcount_channel_id_361bd585_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelcount_channel_id_361bd585_idx ON channels_channelcount USING btree (channel_id, count_type, day);


--
-- Name: channels_channelcount_unsquashed; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelcount_unsquashed ON channels_channelcount USING btree (channel_id, count_type, day) WHERE (NOT is_squashed);


--
-- Name: channels_channelevent_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelevent_6d82f13d ON channels_channelevent USING btree (contact_id);


--
-- Name: channels_channelevent_72eb6c85; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelevent_72eb6c85 ON channels_channelevent USING btree (channel_id);


--
-- Name: channels_channelevent_842dde28; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelevent_842dde28 ON channels_channelevent USING btree (contact_urn_id);


--
-- Name: channels_channelevent_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelevent_9cf869aa ON channels_channelevent USING btree (org_id);


--
-- Name: channels_channelevent_api_view; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelevent_api_view ON channels_channelevent USING btree (org_id, created_on DESC, id DESC) WHERE (is_active = true);


--
-- Name: channels_channelevent_calls_view; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelevent_calls_view ON channels_channelevent USING btree (org_id, "time" DESC) WHERE ((is_active = true) AND ((event_type)::text = ANY ((ARRAY['mt_call'::character varying, 'mt_miss'::character varying, 'mo_call'::character varying, 'mo_miss'::character varying])::text[])));


--
-- Name: channels_channellog_0cc31d7b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channellog_0cc31d7b ON channels_channellog USING btree (msg_id);


--
-- Name: channels_channellog_72eb6c85; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channellog_72eb6c85 ON channels_channellog USING btree (channel_id);


--
-- Name: channels_channellog_7fc8ef54; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channellog_7fc8ef54 ON channels_channellog USING btree (session_id);


--
-- Name: channels_channellog_channel_created_on; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channellog_channel_created_on ON channels_channellog USING btree (channel_id, created_on DESC);


--
-- Name: channels_channelsession_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelsession_6d82f13d ON channels_channelsession USING btree (contact_id);


--
-- Name: channels_channelsession_72eb6c85; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelsession_72eb6c85 ON channels_channelsession USING btree (channel_id);


--
-- Name: channels_channelsession_842dde28; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelsession_842dde28 ON channels_channelsession USING btree (contact_urn_id);


--
-- Name: channels_channelsession_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelsession_9cf869aa ON channels_channelsession USING btree (org_id);


--
-- Name: channels_channelsession_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelsession_b3da0983 ON channels_channelsession USING btree (modified_by_id);


--
-- Name: channels_channelsession_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_channelsession_e93cb7eb ON channels_channelsession USING btree (created_by_id);


--
-- Name: channels_syncevent_72eb6c85; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_syncevent_72eb6c85 ON channels_syncevent USING btree (channel_id);


--
-- Name: channels_syncevent_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_syncevent_b3da0983 ON channels_syncevent USING btree (modified_by_id);


--
-- Name: channels_syncevent_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX channels_syncevent_e93cb7eb ON channels_syncevent USING btree (created_by_id);


--
-- Name: contacts_contact_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contact_9cf869aa ON contacts_contact USING btree (org_id);


--
-- Name: contacts_contact_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contact_b3da0983 ON contacts_contact USING btree (modified_by_id);


--
-- Name: contacts_contact_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contact_e93cb7eb ON contacts_contact USING btree (created_by_id);


--
-- Name: contacts_contact_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contact_name ON contacts_contact USING btree (org_id, upper((name)::text));


--
-- Name: contacts_contact_org_modified_id_where_nontest_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contact_org_modified_id_where_nontest_active ON contacts_contact USING btree (org_id, modified_on DESC, id DESC) WHERE ((is_test = false) AND (is_active = true));


--
-- Name: contacts_contact_org_modified_id_where_nontest_inactive; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contact_org_modified_id_where_nontest_inactive ON contacts_contact USING btree (org_id, modified_on DESC, id DESC) WHERE ((is_test = false) AND (is_active = false));


--
-- Name: contacts_contact_uuid_66fe2f01_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contact_uuid_66fe2f01_like ON contacts_contact USING btree (uuid varchar_pattern_ops);


--
-- Name: contacts_contactfield_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactfield_9cf869aa ON contacts_contactfield USING btree (org_id);


--
-- Name: contacts_contactfield_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactfield_b3da0983 ON contacts_contactfield USING btree (modified_by_id);


--
-- Name: contacts_contactfield_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactfield_e93cb7eb ON contacts_contactfield USING btree (created_by_id);


--
-- Name: contacts_contactgroup_905540a6; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactgroup_905540a6 ON contacts_contactgroup USING btree (import_task_id);


--
-- Name: contacts_contactgroup_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactgroup_9cf869aa ON contacts_contactgroup USING btree (org_id);


--
-- Name: contacts_contactgroup_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactgroup_b3da0983 ON contacts_contactgroup USING btree (modified_by_id);


--
-- Name: contacts_contactgroup_contacts_0b1b2ae4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactgroup_contacts_0b1b2ae4 ON contacts_contactgroup_contacts USING btree (contactgroup_id);


--
-- Name: contacts_contactgroup_contacts_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactgroup_contacts_6d82f13d ON contacts_contactgroup_contacts USING btree (contact_id);


--
-- Name: contacts_contactgroup_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactgroup_e93cb7eb ON contacts_contactgroup USING btree (created_by_id);


--
-- Name: contacts_contactgroup_query_fields_0b1b2ae4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactgroup_query_fields_0b1b2ae4 ON contacts_contactgroup_query_fields USING btree (contactgroup_id);


--
-- Name: contacts_contactgroup_query_fields_0d0cd403; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactgroup_query_fields_0d0cd403 ON contacts_contactgroup_query_fields USING btree (contactfield_id);


--
-- Name: contacts_contactgroup_uuid_377d4c62_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactgroup_uuid_377d4c62_like ON contacts_contactgroup USING btree (uuid varchar_pattern_ops);


--
-- Name: contacts_contactgroupcount_0e939a4f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactgroupcount_0e939a4f ON contacts_contactgroupcount USING btree (group_id);


--
-- Name: contacts_contactgroupcount_unsquashed; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contactgroupcount_unsquashed ON contacts_contactgroupcount USING btree (group_id) WHERE (NOT is_squashed);


--
-- Name: contacts_contacturn_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contacturn_6d82f13d ON contacts_contacturn USING btree (contact_id);


--
-- Name: contacts_contacturn_72eb6c85; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contacturn_72eb6c85 ON contacts_contacturn USING btree (channel_id);


--
-- Name: contacts_contacturn_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contacturn_9cf869aa ON contacts_contacturn USING btree (org_id);


--
-- Name: contacts_contacturn_path; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_contacturn_path ON contacts_contacturn USING btree (org_id, upper((path)::text), contact_id);


--
-- Name: contacts_exportcontactstask_0e939a4f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_exportcontactstask_0e939a4f ON contacts_exportcontactstask USING btree (group_id);


--
-- Name: contacts_exportcontactstask_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_exportcontactstask_9cf869aa ON contacts_exportcontactstask USING btree (org_id);


--
-- Name: contacts_exportcontactstask_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_exportcontactstask_b3da0983 ON contacts_exportcontactstask USING btree (modified_by_id);


--
-- Name: contacts_exportcontactstask_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_exportcontactstask_e93cb7eb ON contacts_exportcontactstask USING btree (created_by_id);


--
-- Name: contacts_exportcontactstask_uuid_aad904fe_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX contacts_exportcontactstask_uuid_aad904fe_like ON contacts_exportcontactstask USING btree (uuid varchar_pattern_ops);


--
-- Name: csv_imports_importtask_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX csv_imports_importtask_b3da0983 ON csv_imports_importtask USING btree (modified_by_id);


--
-- Name: csv_imports_importtask_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX csv_imports_importtask_e93cb7eb ON csv_imports_importtask USING btree (created_by_id);


--
-- Name: django_session_de54fa62; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_session_de54fa62 ON django_session USING btree (expire_date);


--
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_session_session_key_c0390e0f_like ON django_session USING btree (session_key varchar_pattern_ops);


--
-- Name: django_site_domain_a2e37b91_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_site_domain_a2e37b91_like ON django_site USING btree (domain varchar_pattern_ops);


--
-- Name: flows_actionlog_0acf093b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_actionlog_0acf093b ON flows_actionlog USING btree (run_id);


--
-- Name: flows_actionset_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_actionset_7f26ac5b ON flows_actionset USING btree (flow_id);


--
-- Name: flows_actionset_uuid_a7003ccb_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_actionset_uuid_a7003ccb_like ON flows_actionset USING btree (uuid varchar_pattern_ops);


--
-- Name: flows_exportflowresultstask_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_exportflowresultstask_9cf869aa ON flows_exportflowresultstask USING btree (org_id);


--
-- Name: flows_exportflowresultstask_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_exportflowresultstask_b3da0983 ON flows_exportflowresultstask USING btree (modified_by_id);


--
-- Name: flows_exportflowresultstask_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_exportflowresultstask_e93cb7eb ON flows_exportflowresultstask USING btree (created_by_id);


--
-- Name: flows_exportflowresultstask_flows_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_exportflowresultstask_flows_7f26ac5b ON flows_exportflowresultstask_flows USING btree (flow_id);


--
-- Name: flows_exportflowresultstask_flows_b21ac655; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_exportflowresultstask_flows_b21ac655 ON flows_exportflowresultstask_flows USING btree (exportflowresultstask_id);


--
-- Name: flows_exportflowresultstask_uuid_ed7e2021_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_exportflowresultstask_uuid_ed7e2021_like ON flows_exportflowresultstask USING btree (uuid varchar_pattern_ops);


--
-- Name: flows_flow_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flow_9cf869aa ON flows_flow USING btree (org_id);


--
-- Name: flows_flow_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flow_b3da0983 ON flows_flow USING btree (modified_by_id);


--
-- Name: flows_flow_bc7c970b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flow_bc7c970b ON flows_flow USING btree (saved_by_id);


--
-- Name: flows_flow_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flow_e93cb7eb ON flows_flow USING btree (created_by_id);


--
-- Name: flows_flow_entry_uuid_e14448bc_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flow_entry_uuid_e14448bc_like ON flows_flow USING btree (entry_uuid varchar_pattern_ops);


--
-- Name: flows_flow_labels_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flow_labels_7f26ac5b ON flows_flow_labels USING btree (flow_id);


--
-- Name: flows_flow_labels_da1e9929; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flow_labels_da1e9929 ON flows_flow_labels USING btree (flowlabel_id);


--
-- Name: flows_flow_uuid_a2114745_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flow_uuid_a2114745_like ON flows_flow USING btree (uuid varchar_pattern_ops);


--
-- Name: flows_flowlabel_6be37982; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowlabel_6be37982 ON flows_flowlabel USING btree (parent_id);


--
-- Name: flows_flowlabel_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowlabel_9cf869aa ON flows_flowlabel USING btree (org_id);


--
-- Name: flows_flowlabel_uuid_133646e5_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowlabel_uuid_133646e5_like ON flows_flowlabel USING btree (uuid varchar_pattern_ops);


--
-- Name: flows_flownodecount_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flownodecount_7f26ac5b ON flows_flownodecount USING btree (flow_id);


--
-- Name: flows_flownodecount_b0074f9e; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flownodecount_b0074f9e ON flows_flownodecount USING btree (node_uuid);


--
-- Name: flows_flowpathcount_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowpathcount_7f26ac5b ON flows_flowpathcount USING btree (flow_id);


--
-- Name: flows_flowpathcount_flow_id_c2f02792_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowpathcount_flow_id_c2f02792_idx ON flows_flowpathcount USING btree (flow_id, from_uuid, to_uuid, period);


--
-- Name: flows_flowpathcount_unsquashed; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowpathcount_unsquashed ON flows_flowpathcount USING btree (flow_id, from_uuid, to_uuid, period) WHERE (NOT is_squashed);


--
-- Name: flows_flowpathrecentstep_bef491d2; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowpathrecentstep_bef491d2 ON flows_flowpathrecentstep USING btree (step_id);


--
-- Name: flows_flowpathrecentstep_from_to_left; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowpathrecentstep_from_to_left ON flows_flowpathrecentstep USING btree (from_uuid, to_uuid, left_on DESC);


--
-- Name: flows_flowrevision_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrevision_7f26ac5b ON flows_flowrevision USING btree (flow_id);


--
-- Name: flows_flowrevision_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrevision_b3da0983 ON flows_flowrevision USING btree (modified_by_id);


--
-- Name: flows_flowrevision_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrevision_e93cb7eb ON flows_flowrevision USING btree (created_by_id);


--
-- Name: flows_flowrun_31174c9a; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_31174c9a ON flows_flowrun USING btree (submitted_by_id);


--
-- Name: flows_flowrun_324ac644; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_324ac644 ON flows_flowrun USING btree (start_id);


--
-- Name: flows_flowrun_6be37982; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_6be37982 ON flows_flowrun USING btree (parent_id);


--
-- Name: flows_flowrun_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_6d82f13d ON flows_flowrun USING btree (contact_id);


--
-- Name: flows_flowrun_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_7f26ac5b ON flows_flowrun USING btree (flow_id);


--
-- Name: flows_flowrun_7fc8ef54; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_7fc8ef54 ON flows_flowrun USING btree (session_id);


--
-- Name: flows_flowrun_expires_on; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_expires_on ON flows_flowrun USING btree (expires_on) WHERE (is_active = true);


--
-- Name: flows_flowrun_flow_modified_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_flow_modified_id ON flows_flowrun USING btree (flow_id, modified_on DESC, id DESC);


--
-- Name: flows_flowrun_flow_modified_id_where_responded; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_flow_modified_id_where_responded ON flows_flowrun USING btree (flow_id, modified_on DESC, id DESC) WHERE (responded = true);


--
-- Name: flows_flowrun_null_expired_on; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_null_expired_on ON flows_flowrun USING btree (exited_on) WHERE (exited_on IS NULL);


--
-- Name: flows_flowrun_org_modified_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_org_modified_id ON flows_flowrun USING btree (org_id, modified_on DESC, id DESC);


--
-- Name: flows_flowrun_org_modified_id_where_responded; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_org_modified_id_where_responded ON flows_flowrun USING btree (org_id, modified_on DESC, id DESC) WHERE (responded = true);


--
-- Name: flows_flowrun_parent_created_on_not_null; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_parent_created_on_not_null ON flows_flowrun USING btree (parent_id, created_on DESC) WHERE (parent_id IS NOT NULL);


--
-- Name: flows_flowrun_timeout_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowrun_timeout_active ON flows_flowrun USING btree (timeout_on) WHERE ((is_active = true) AND (timeout_on IS NOT NULL));


--
-- Name: flows_flowruncount_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowruncount_7f26ac5b ON flows_flowruncount USING btree (flow_id);


--
-- Name: flows_flowruncount_flow_id_eef1051f_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowruncount_flow_id_eef1051f_idx ON flows_flowruncount USING btree (flow_id, exit_type);


--
-- Name: flows_flowruncount_unsquashed; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowruncount_unsquashed ON flows_flowruncount USING btree (flow_id, exit_type) WHERE (NOT is_squashed);


--
-- Name: flows_flowstart_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstart_7f26ac5b ON flows_flowstart USING btree (flow_id);


--
-- Name: flows_flowstart_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstart_b3da0983 ON flows_flowstart USING btree (modified_by_id);


--
-- Name: flows_flowstart_contacts_3f45c555; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstart_contacts_3f45c555 ON flows_flowstart_contacts USING btree (flowstart_id);


--
-- Name: flows_flowstart_contacts_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstart_contacts_6d82f13d ON flows_flowstart_contacts USING btree (contact_id);


--
-- Name: flows_flowstart_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstart_e93cb7eb ON flows_flowstart USING btree (created_by_id);


--
-- Name: flows_flowstart_groups_0b1b2ae4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstart_groups_0b1b2ae4 ON flows_flowstart_groups USING btree (contactgroup_id);


--
-- Name: flows_flowstart_groups_3f45c555; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstart_groups_3f45c555 ON flows_flowstart_groups USING btree (flowstart_id);


--
-- Name: flows_flowstep_017416d4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstep_017416d4 ON flows_flowstep USING btree (step_uuid);


--
-- Name: flows_flowstep_0acf093b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstep_0acf093b ON flows_flowstep USING btree (run_id);


--
-- Name: flows_flowstep_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstep_6d82f13d ON flows_flowstep USING btree (contact_id);


--
-- Name: flows_flowstep_a8b6e9f0; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstep_a8b6e9f0 ON flows_flowstep USING btree (left_on);


--
-- Name: flows_flowstep_broadcasts_b0cb7d59; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstep_broadcasts_b0cb7d59 ON flows_flowstep_broadcasts USING btree (broadcast_id);


--
-- Name: flows_flowstep_broadcasts_c01a422b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstep_broadcasts_c01a422b ON flows_flowstep_broadcasts USING btree (flowstep_id);


--
-- Name: flows_flowstep_messages_0cc31d7b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstep_messages_0cc31d7b ON flows_flowstep_messages USING btree (msg_id);


--
-- Name: flows_flowstep_messages_c01a422b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstep_messages_c01a422b ON flows_flowstep_messages USING btree (flowstep_id);


--
-- Name: flows_flowstep_step_uuid_5b365bbf_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_flowstep_step_uuid_5b365bbf_like ON flows_flowstep USING btree (step_uuid varchar_pattern_ops);


--
-- Name: flows_ruleset_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_ruleset_7f26ac5b ON flows_ruleset USING btree (flow_id);


--
-- Name: flows_ruleset_uuid_c303fd70_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flows_ruleset_uuid_c303fd70_like ON flows_ruleset USING btree (uuid varchar_pattern_ops);


--
-- Name: guardian_groupobjectpermission_0e939a4f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX guardian_groupobjectpermission_0e939a4f ON guardian_groupobjectpermission USING btree (group_id);


--
-- Name: guardian_groupobjectpermission_417f1b1c; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX guardian_groupobjectpermission_417f1b1c ON guardian_groupobjectpermission USING btree (content_type_id);


--
-- Name: guardian_groupobjectpermission_8373b171; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX guardian_groupobjectpermission_8373b171 ON guardian_groupobjectpermission USING btree (permission_id);


--
-- Name: guardian_userobjectpermission_417f1b1c; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX guardian_userobjectpermission_417f1b1c ON guardian_userobjectpermission USING btree (content_type_id);


--
-- Name: guardian_userobjectpermission_8373b171; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX guardian_userobjectpermission_8373b171 ON guardian_userobjectpermission USING btree (permission_id);


--
-- Name: guardian_userobjectpermission_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX guardian_userobjectpermission_e8701ad4 ON guardian_userobjectpermission USING btree (user_id);


--
-- Name: locations_adminboundary_3cfbd988; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_adminboundary_3cfbd988 ON locations_adminboundary USING btree (rght);


--
-- Name: locations_adminboundary_656442a0; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_adminboundary_656442a0 ON locations_adminboundary USING btree (tree_id);


--
-- Name: locations_adminboundary_6be37982; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_adminboundary_6be37982 ON locations_adminboundary USING btree (parent_id);


--
-- Name: locations_adminboundary_caf7cc51; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_adminboundary_caf7cc51 ON locations_adminboundary USING btree (lft);


--
-- Name: locations_adminboundary_geometry_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_adminboundary_geometry_id ON locations_adminboundary USING gist (geometry);


--
-- Name: locations_adminboundary_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_adminboundary_name ON locations_adminboundary USING btree (upper((name)::text));


--
-- Name: locations_adminboundary_osm_id_ada345c4_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_adminboundary_osm_id_ada345c4_like ON locations_adminboundary USING btree (osm_id varchar_pattern_ops);


--
-- Name: locations_adminboundary_simplified_geometry_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_adminboundary_simplified_geometry_id ON locations_adminboundary USING gist (simplified_geometry);


--
-- Name: locations_boundaryalias_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_boundaryalias_9cf869aa ON locations_boundaryalias USING btree (org_id);


--
-- Name: locations_boundaryalias_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_boundaryalias_b3da0983 ON locations_boundaryalias USING btree (modified_by_id);


--
-- Name: locations_boundaryalias_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_boundaryalias_e93cb7eb ON locations_boundaryalias USING btree (created_by_id);


--
-- Name: locations_boundaryalias_eb01ad15; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_boundaryalias_eb01ad15 ON locations_boundaryalias USING btree (boundary_id);


--
-- Name: locations_boundaryalias_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX locations_boundaryalias_name ON locations_boundaryalias USING btree (upper((name)::text));


--
-- Name: msgs_broadcast_6be37982; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_6be37982 ON msgs_broadcast USING btree (parent_id);


--
-- Name: msgs_broadcast_6d10fce5; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_6d10fce5 ON msgs_broadcast USING btree (created_on);


--
-- Name: msgs_broadcast_72eb6c85; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_72eb6c85 ON msgs_broadcast USING btree (channel_id);


--
-- Name: msgs_broadcast_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_9cf869aa ON msgs_broadcast USING btree (org_id);


--
-- Name: msgs_broadcast_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_b3da0983 ON msgs_broadcast USING btree (modified_by_id);


--
-- Name: msgs_broadcast_contacts_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_contacts_6d82f13d ON msgs_broadcast_contacts USING btree (contact_id);


--
-- Name: msgs_broadcast_contacts_b0cb7d59; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_contacts_b0cb7d59 ON msgs_broadcast_contacts USING btree (broadcast_id);


--
-- Name: msgs_broadcast_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_e93cb7eb ON msgs_broadcast USING btree (created_by_id);


--
-- Name: msgs_broadcast_groups_0b1b2ae4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_groups_0b1b2ae4 ON msgs_broadcast_groups USING btree (contactgroup_id);


--
-- Name: msgs_broadcast_groups_b0cb7d59; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_groups_b0cb7d59 ON msgs_broadcast_groups USING btree (broadcast_id);


--
-- Name: msgs_broadcast_recipients_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_recipients_6d82f13d ON msgs_broadcast_recipients USING btree (contact_id);


--
-- Name: msgs_broadcast_recipients_b0cb7d59; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_recipients_b0cb7d59 ON msgs_broadcast_recipients USING btree (broadcast_id);


--
-- Name: msgs_broadcast_urns_5a8e6a7d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_urns_5a8e6a7d ON msgs_broadcast_urns USING btree (contacturn_id);


--
-- Name: msgs_broadcast_urns_b0cb7d59; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcast_urns_b0cb7d59 ON msgs_broadcast_urns USING btree (broadcast_id);


--
-- Name: msgs_broadcasts_org_created_id_where_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_broadcasts_org_created_id_where_active ON msgs_broadcast USING btree (org_id, created_on DESC, id DESC) WHERE (is_active = true);


--
-- Name: msgs_exportmessagestask_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_exportmessagestask_9cf869aa ON msgs_exportmessagestask USING btree (org_id);


--
-- Name: msgs_exportmessagestask_abec2aca; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_exportmessagestask_abec2aca ON msgs_exportmessagestask USING btree (label_id);


--
-- Name: msgs_exportmessagestask_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_exportmessagestask_b3da0983 ON msgs_exportmessagestask USING btree (modified_by_id);


--
-- Name: msgs_exportmessagestask_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_exportmessagestask_e93cb7eb ON msgs_exportmessagestask USING btree (created_by_id);


--
-- Name: msgs_exportmessagestask_groups_0b1b2ae4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_exportmessagestask_groups_0b1b2ae4 ON msgs_exportmessagestask_groups USING btree (contactgroup_id);


--
-- Name: msgs_exportmessagestask_groups_9ad8bdea; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_exportmessagestask_groups_9ad8bdea ON msgs_exportmessagestask_groups USING btree (exportmessagestask_id);


--
-- Name: msgs_exportmessagestask_uuid_a9d02f48_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_exportmessagestask_uuid_a9d02f48_like ON msgs_exportmessagestask USING btree (uuid varchar_pattern_ops);


--
-- Name: msgs_label_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_label_9cf869aa ON msgs_label USING btree (org_id);


--
-- Name: msgs_label_a8a44dbb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_label_a8a44dbb ON msgs_label USING btree (folder_id);


--
-- Name: msgs_label_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_label_b3da0983 ON msgs_label USING btree (modified_by_id);


--
-- Name: msgs_label_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_label_e93cb7eb ON msgs_label USING btree (created_by_id);


--
-- Name: msgs_label_uuid_d9a956c8_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_label_uuid_d9a956c8_like ON msgs_label USING btree (uuid varchar_pattern_ops);


--
-- Name: msgs_labelcount_abec2aca; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_labelcount_abec2aca ON msgs_labelcount USING btree (label_id);


--
-- Name: msgs_msg_6d10fce5; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_6d10fce5 ON msgs_msg USING btree (created_on);


--
-- Name: msgs_msg_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_6d82f13d ON msgs_msg USING btree (contact_id);


--
-- Name: msgs_msg_72eb6c85; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_72eb6c85 ON msgs_msg USING btree (channel_id);


--
-- Name: msgs_msg_7fc8ef54; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_7fc8ef54 ON msgs_msg USING btree (session_id);


--
-- Name: msgs_msg_842dde28; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_842dde28 ON msgs_msg USING btree (contact_urn_id);


--
-- Name: msgs_msg_9acb4454; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_9acb4454 ON msgs_msg USING btree (status);


--
-- Name: msgs_msg_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_9cf869aa ON msgs_msg USING btree (org_id);


--
-- Name: msgs_msg_a5d9fd84; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_a5d9fd84 ON msgs_msg USING btree (topup_id);


--
-- Name: msgs_msg_b0cb7d59; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_b0cb7d59 ON msgs_msg USING btree (broadcast_id);


--
-- Name: msgs_msg_external_id_where_nonnull; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_external_id_where_nonnull ON msgs_msg USING btree (external_id) WHERE (external_id IS NOT NULL);


--
-- Name: msgs_msg_f79b1d64; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_f79b1d64 ON msgs_msg USING btree (visibility);


--
-- Name: msgs_msg_labels_0cc31d7b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_labels_0cc31d7b ON msgs_msg_labels USING btree (msg_id);


--
-- Name: msgs_msg_labels_abec2aca; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_labels_abec2aca ON msgs_msg_labels USING btree (label_id);


--
-- Name: msgs_msg_org_created_id_where_outbound_visible_failed; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_org_created_id_where_outbound_visible_failed ON msgs_msg USING btree (org_id, created_on DESC, id DESC) WHERE (((direction)::text = 'O'::text) AND ((visibility)::text = 'V'::text) AND ((status)::text = 'F'::text));


--
-- Name: msgs_msg_org_created_id_where_outbound_visible_outbox; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_org_created_id_where_outbound_visible_outbox ON msgs_msg USING btree (org_id, created_on DESC, id DESC) WHERE (((direction)::text = 'O'::text) AND ((visibility)::text = 'V'::text) AND ((status)::text = ANY ((ARRAY['P'::character varying, 'Q'::character varying])::text[])));


--
-- Name: msgs_msg_org_created_id_where_outbound_visible_sent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_org_created_id_where_outbound_visible_sent ON msgs_msg USING btree (org_id, created_on DESC, id DESC) WHERE (((direction)::text = 'O'::text) AND ((visibility)::text = 'V'::text) AND ((status)::text = ANY ((ARRAY['W'::character varying, 'S'::character varying, 'D'::character varying])::text[])));


--
-- Name: msgs_msg_org_modified_id_where_inbound; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_org_modified_id_where_inbound ON msgs_msg USING btree (org_id, modified_on DESC, id DESC) WHERE ((direction)::text = 'I'::text);


--
-- Name: msgs_msg_responded_to_not_null; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_responded_to_not_null ON msgs_msg USING btree (response_to_id) WHERE (response_to_id IS NOT NULL);


--
-- Name: msgs_msg_status_869a44ea_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_status_869a44ea_like ON msgs_msg USING btree (status varchar_pattern_ops);


--
-- Name: msgs_msg_visibility_f61b5308_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_visibility_f61b5308_like ON msgs_msg USING btree (visibility varchar_pattern_ops);


--
-- Name: msgs_msg_visibility_type_created_id_where_inbound; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_msg_visibility_type_created_id_where_inbound ON msgs_msg USING btree (org_id, visibility, msg_type, created_on DESC, id DESC) WHERE ((direction)::text = 'I'::text);


--
-- Name: msgs_systemlabel_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_systemlabel_9cf869aa ON msgs_systemlabelcount USING btree (org_id);


--
-- Name: msgs_systemlabel_org_id_65875516_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_systemlabel_org_id_65875516_idx ON msgs_systemlabelcount USING btree (org_id, label_type);


--
-- Name: msgs_systemlabel_unsquashed; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX msgs_systemlabel_unsquashed ON msgs_systemlabelcount USING btree (org_id, label_type) WHERE (NOT is_squashed);


--
-- Name: org_test_contacts; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX org_test_contacts ON contacts_contact USING btree (org_id) WHERE (is_test = true);


--
-- Name: orgs_creditalert_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_creditalert_9cf869aa ON orgs_creditalert USING btree (org_id);


--
-- Name: orgs_creditalert_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_creditalert_b3da0983 ON orgs_creditalert USING btree (modified_by_id);


--
-- Name: orgs_creditalert_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_creditalert_e93cb7eb ON orgs_creditalert USING btree (created_by_id);


--
-- Name: orgs_debit_9e459dc4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_debit_9e459dc4 ON orgs_debit USING btree (beneficiary_id);


--
-- Name: orgs_debit_a5d9fd84; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_debit_a5d9fd84 ON orgs_debit USING btree (topup_id);


--
-- Name: orgs_debit_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_debit_e93cb7eb ON orgs_debit USING btree (created_by_id);


--
-- Name: orgs_debit_unsquashed_purged; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_debit_unsquashed_purged ON orgs_debit USING btree (topup_id) WHERE ((NOT is_squashed) AND ((debit_type)::text = 'P'::text));


--
-- Name: orgs_invitation_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_invitation_9cf869aa ON orgs_invitation USING btree (org_id);


--
-- Name: orgs_invitation_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_invitation_b3da0983 ON orgs_invitation USING btree (modified_by_id);


--
-- Name: orgs_invitation_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_invitation_e93cb7eb ON orgs_invitation USING btree (created_by_id);


--
-- Name: orgs_invitation_secret_fa4b1204_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_invitation_secret_fa4b1204_like ON orgs_invitation USING btree (secret varchar_pattern_ops);


--
-- Name: orgs_language_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_language_9cf869aa ON orgs_language USING btree (org_id);


--
-- Name: orgs_language_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_language_b3da0983 ON orgs_language USING btree (modified_by_id);


--
-- Name: orgs_language_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_language_e93cb7eb ON orgs_language USING btree (created_by_id);


--
-- Name: orgs_org_199f5f21; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_199f5f21 ON orgs_org USING btree (primary_language_id);


--
-- Name: orgs_org_6be37982; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_6be37982 ON orgs_org USING btree (parent_id);


--
-- Name: orgs_org_93bfec8a; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_93bfec8a ON orgs_org USING btree (country_id);


--
-- Name: orgs_org_administrators_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_administrators_9cf869aa ON orgs_org_administrators USING btree (org_id);


--
-- Name: orgs_org_administrators_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_administrators_e8701ad4 ON orgs_org_administrators USING btree (user_id);


--
-- Name: orgs_org_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_b3da0983 ON orgs_org USING btree (modified_by_id);


--
-- Name: orgs_org_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_e93cb7eb ON orgs_org USING btree (created_by_id);


--
-- Name: orgs_org_editors_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_editors_9cf869aa ON orgs_org_editors USING btree (org_id);


--
-- Name: orgs_org_editors_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_editors_e8701ad4 ON orgs_org_editors USING btree (user_id);


--
-- Name: orgs_org_slug_203caf0d_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_slug_203caf0d_like ON orgs_org USING btree (slug varchar_pattern_ops);


--
-- Name: orgs_org_surveyors_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_surveyors_9cf869aa ON orgs_org_surveyors USING btree (org_id);


--
-- Name: orgs_org_surveyors_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_surveyors_e8701ad4 ON orgs_org_surveyors USING btree (user_id);


--
-- Name: orgs_org_viewers_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_viewers_9cf869aa ON orgs_org_viewers USING btree (org_id);


--
-- Name: orgs_org_viewers_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_org_viewers_e8701ad4 ON orgs_org_viewers USING btree (user_id);


--
-- Name: orgs_topup_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_topup_9cf869aa ON orgs_topup USING btree (org_id);


--
-- Name: orgs_topup_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_topup_b3da0983 ON orgs_topup USING btree (modified_by_id);


--
-- Name: orgs_topup_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_topup_e93cb7eb ON orgs_topup USING btree (created_by_id);


--
-- Name: orgs_topupcredits_a5d9fd84; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_topupcredits_a5d9fd84 ON orgs_topupcredits USING btree (topup_id);


--
-- Name: orgs_topupcredits_unsquashed; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_topupcredits_unsquashed ON orgs_topupcredits USING btree (topup_id) WHERE (NOT is_squashed);


--
-- Name: orgs_usersettings_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orgs_usersettings_e8701ad4 ON orgs_usersettings USING btree (user_id);


--
-- Name: public_lead_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX public_lead_b3da0983 ON public_lead USING btree (modified_by_id);


--
-- Name: public_lead_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX public_lead_e93cb7eb ON public_lead USING btree (created_by_id);


--
-- Name: public_video_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX public_video_b3da0983 ON public_video USING btree (modified_by_id);


--
-- Name: public_video_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX public_video_e93cb7eb ON public_video USING btree (created_by_id);


--
-- Name: reports_report_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX reports_report_9cf869aa ON reports_report USING btree (org_id);


--
-- Name: reports_report_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX reports_report_b3da0983 ON reports_report USING btree (modified_by_id);


--
-- Name: reports_report_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX reports_report_e93cb7eb ON reports_report USING btree (created_by_id);


--
-- Name: schedules_schedule_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX schedules_schedule_b3da0983 ON schedules_schedule USING btree (modified_by_id);


--
-- Name: schedules_schedule_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX schedules_schedule_e93cb7eb ON schedules_schedule USING btree (created_by_id);


--
-- Name: triggers_trigger_7f26ac5b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX triggers_trigger_7f26ac5b ON triggers_trigger USING btree (flow_id);


--
-- Name: triggers_trigger_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX triggers_trigger_9cf869aa ON triggers_trigger USING btree (org_id);


--
-- Name: triggers_trigger_b3da0983; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX triggers_trigger_b3da0983 ON triggers_trigger USING btree (modified_by_id);


--
-- Name: triggers_trigger_contacts_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX triggers_trigger_contacts_6d82f13d ON triggers_trigger_contacts USING btree (contact_id);


--
-- Name: triggers_trigger_contacts_b10b1f9f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX triggers_trigger_contacts_b10b1f9f ON triggers_trigger_contacts USING btree (trigger_id);


--
-- Name: triggers_trigger_e93cb7eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX triggers_trigger_e93cb7eb ON triggers_trigger USING btree (created_by_id);


--
-- Name: triggers_trigger_groups_0b1b2ae4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX triggers_trigger_groups_0b1b2ae4 ON triggers_trigger_groups USING btree (contactgroup_id);


--
-- Name: triggers_trigger_groups_b10b1f9f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX triggers_trigger_groups_b10b1f9f ON triggers_trigger_groups USING btree (trigger_id);


--
-- Name: users_failedlogin_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX users_failedlogin_e8701ad4 ON users_failedlogin USING btree (user_id);


--
-- Name: users_passwordhistory_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX users_passwordhistory_e8701ad4 ON users_passwordhistory USING btree (user_id);


--
-- Name: users_recoverytoken_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX users_recoverytoken_e8701ad4 ON users_recoverytoken USING btree (user_id);


--
-- Name: users_recoverytoken_token_c8594dc8_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX users_recoverytoken_token_c8594dc8_like ON users_recoverytoken USING btree (token varchar_pattern_ops);


--
-- Name: values_value_0acf093b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_0acf093b ON values_value USING btree (run_id);


--
-- Name: values_value_4d0a6d0f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_4d0a6d0f ON values_value USING btree (ruleset_id);


--
-- Name: values_value_6d82f13d; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_6d82f13d ON values_value USING btree (contact_id);


--
-- Name: values_value_91709fb3; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_91709fb3 ON values_value USING btree (location_value_id);


--
-- Name: values_value_9cf869aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_9cf869aa ON values_value USING btree (org_id);


--
-- Name: values_value_9ff6aeda; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_9ff6aeda ON values_value USING btree (contact_field_id);


--
-- Name: values_value_a3329707; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_a3329707 ON values_value USING btree (rule_uuid);


--
-- Name: values_value_contact_field_location_not_null; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_contact_field_location_not_null ON values_value USING btree (contact_field_id, location_value_id) WHERE ((contact_field_id IS NOT NULL) AND (location_value_id IS NOT NULL));


--
-- Name: values_value_field_datetime_value_not_null; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_field_datetime_value_not_null ON values_value USING btree (contact_field_id, datetime_value) WHERE ((contact_field_id IS NOT NULL) AND (datetime_value IS NOT NULL));


--
-- Name: values_value_field_decimal_value_not_null; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_field_decimal_value_not_null ON values_value USING btree (contact_field_id, decimal_value) WHERE ((contact_field_id IS NOT NULL) AND (decimal_value IS NOT NULL));


--
-- Name: values_value_field_string_value_concat; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_field_string_value_concat ON values_value USING btree ((((contact_field_id || '|'::text) || upper(string_value))));


--
-- Name: values_value_rule_uuid_5b1a260a_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX values_value_rule_uuid_5b1a260a_like ON values_value USING btree (rule_uuid varchar_pattern_ops);


--
-- Name: contacts_contact contact_check_update_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER contact_check_update_trg BEFORE UPDATE OF is_test, is_blocked, is_stopped ON contacts_contact FOR EACH ROW EXECUTE PROCEDURE contact_check_update();


--
-- Name: msgs_broadcast temba_broadcast_on_change_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_broadcast_on_change_trg AFTER INSERT OR DELETE OR UPDATE ON msgs_broadcast FOR EACH ROW EXECUTE PROCEDURE temba_broadcast_on_change();


--
-- Name: msgs_broadcast temba_broadcast_on_truncate_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_broadcast_on_truncate_trg AFTER TRUNCATE ON msgs_broadcast FOR EACH STATEMENT EXECUTE PROCEDURE temba_broadcast_on_change();


--
-- Name: channels_channelevent temba_channelevent_on_change_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_channelevent_on_change_trg AFTER INSERT OR DELETE OR UPDATE ON channels_channelevent FOR EACH ROW EXECUTE PROCEDURE temba_channelevent_on_change();


--
-- Name: channels_channelevent temba_channelevent_on_truncate_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_channelevent_on_truncate_trg AFTER TRUNCATE ON channels_channelevent FOR EACH STATEMENT EXECUTE PROCEDURE temba_channelevent_on_change();


--
-- Name: channels_channellog temba_channellog_truncate_channelcount; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_channellog_truncate_channelcount AFTER TRUNCATE ON channels_channellog FOR EACH STATEMENT EXECUTE PROCEDURE temba_update_channellog_count();


--
-- Name: channels_channellog temba_channellog_update_channelcount; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_channellog_update_channelcount AFTER INSERT OR DELETE OR UPDATE OF is_error, channel_id ON channels_channellog FOR EACH ROW EXECUTE PROCEDURE temba_update_channellog_count();


--
-- Name: flows_flowrun temba_flowrun_truncate_flowruncount; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_flowrun_truncate_flowruncount AFTER TRUNCATE ON flows_flowrun FOR EACH STATEMENT EXECUTE PROCEDURE temba_update_flowruncount();


--
-- Name: flows_flowrun temba_flowrun_update_flowruncount; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_flowrun_update_flowruncount AFTER INSERT OR DELETE OR UPDATE OF exit_type ON flows_flowrun FOR EACH ROW EXECUTE PROCEDURE temba_update_flowruncount();


--
-- Name: flows_flowstep temba_flowstep_truncate_flowpathcount; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_flowstep_truncate_flowpathcount AFTER TRUNCATE ON flows_flowstep FOR EACH STATEMENT EXECUTE PROCEDURE temba_update_flowpathcount();


--
-- Name: flows_flowstep temba_flowstep_update_flowpathcount; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_flowstep_update_flowpathcount AFTER INSERT OR DELETE OR UPDATE OF left_on ON flows_flowstep FOR EACH ROW EXECUTE PROCEDURE temba_update_flowpathcount();


--
-- Name: msgs_msg temba_msg_clear_channelcount; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_msg_clear_channelcount AFTER TRUNCATE ON msgs_msg FOR EACH STATEMENT EXECUTE PROCEDURE temba_update_channelcount();


--
-- Name: msgs_msg_labels temba_msg_labels_on_change_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_msg_labels_on_change_trg AFTER INSERT OR DELETE ON msgs_msg_labels FOR EACH ROW EXECUTE PROCEDURE temba_msg_labels_on_change();


--
-- Name: msgs_msg_labels temba_msg_labels_on_truncate_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_msg_labels_on_truncate_trg AFTER TRUNCATE ON msgs_msg_labels FOR EACH STATEMENT EXECUTE PROCEDURE temba_msg_labels_on_change();


--
-- Name: msgs_msg temba_msg_on_change_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_msg_on_change_trg AFTER INSERT OR DELETE OR UPDATE ON msgs_msg FOR EACH ROW EXECUTE PROCEDURE temba_msg_on_change();


--
-- Name: msgs_msg temba_msg_on_truncate_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_msg_on_truncate_trg AFTER TRUNCATE ON msgs_msg FOR EACH STATEMENT EXECUTE PROCEDURE temba_msg_on_change();


--
-- Name: msgs_msg temba_msg_update_channelcount; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_msg_update_channelcount AFTER INSERT OR UPDATE OF direction, msg_type, created_on ON msgs_msg FOR EACH ROW EXECUTE PROCEDURE temba_update_channelcount();


--
-- Name: orgs_debit temba_when_debit_update_then_update_topupcredits_for_debit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_when_debit_update_then_update_topupcredits_for_debit AFTER INSERT OR DELETE OR UPDATE OF topup_id ON orgs_debit FOR EACH ROW EXECUTE PROCEDURE temba_update_topupcredits_for_debit();


--
-- Name: msgs_msg temba_when_msgs_update_then_update_topupcredits; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER temba_when_msgs_update_then_update_topupcredits AFTER INSERT OR DELETE OR UPDATE OF topup_id ON msgs_msg FOR EACH ROW EXECUTE PROCEDURE temba_update_topupcredits();


--
-- Name: contacts_contactgroup_contacts when_contact_groups_changed_then_update_count_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER when_contact_groups_changed_then_update_count_trg AFTER INSERT OR DELETE ON contacts_contactgroup_contacts FOR EACH ROW EXECUTE PROCEDURE update_group_count();


--
-- Name: contacts_contactgroup_contacts when_contact_groups_truncate_then_update_count_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER when_contact_groups_truncate_then_update_count_trg AFTER TRUNCATE ON contacts_contactgroup_contacts FOR EACH STATEMENT EXECUTE PROCEDURE update_group_count();


--
-- Name: contacts_contact when_contacts_changed_then_update_groups_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER when_contacts_changed_then_update_groups_trg AFTER INSERT OR UPDATE ON contacts_contact FOR EACH ROW EXECUTE PROCEDURE update_contact_system_groups();


--
-- Name: flows_exportflowresultstask_flows D351adf3ef72c1d7d251e03ef7e65a9e; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_exportflowresultstask_flows
    ADD CONSTRAINT "D351adf3ef72c1d7d251e03ef7e65a9e" FOREIGN KEY (exportflowresultstask_id) REFERENCES flows_exportflowresultstask(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: airtime_airtimetransfer airtime_airtimetrans_channel_id_26d84428_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY airtime_airtimetransfer
    ADD CONSTRAINT airtime_airtimetrans_channel_id_26d84428_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: airtime_airtimetransfer airtime_airtimetrans_contact_id_e90a2275_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY airtime_airtimetransfer
    ADD CONSTRAINT airtime_airtimetrans_contact_id_e90a2275_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: airtime_airtimetransfer airtime_airtimetransfer_created_by_id_efb7f775_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY airtime_airtimetransfer
    ADD CONSTRAINT airtime_airtimetransfer_created_by_id_efb7f775_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: airtime_airtimetransfer airtime_airtimetransfer_modified_by_id_4682a18c_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY airtime_airtimetransfer
    ADD CONSTRAINT airtime_airtimetransfer_modified_by_id_4682a18c_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: airtime_airtimetransfer airtime_airtimetransfer_org_id_3eef5867_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY airtime_airtimetransfer
    ADD CONSTRAINT airtime_airtimetransfer_org_id_3eef5867_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_apitoken api_apitoken_org_id_b1411661_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_apitoken
    ADD CONSTRAINT api_apitoken_org_id_b1411661_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_apitoken api_apitoken_role_id_391adbf5_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_apitoken
    ADD CONSTRAINT api_apitoken_role_id_391adbf5_fk_auth_group_id FOREIGN KEY (role_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_apitoken api_apitoken_user_id_9cffaf33_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_apitoken
    ADD CONSTRAINT api_apitoken_user_id_9cffaf33_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_resthook api_resthook_created_by_id_26c82721_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_resthook
    ADD CONSTRAINT api_resthook_created_by_id_26c82721_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_resthook api_resthook_modified_by_id_d5b8e394_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_resthook
    ADD CONSTRAINT api_resthook_modified_by_id_d5b8e394_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_resthook api_resthook_org_id_3ac815fe_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_resthook
    ADD CONSTRAINT api_resthook_org_id_3ac815fe_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_resthooksubscriber api_resthooksubscriber_created_by_id_ff38300d_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_resthooksubscriber
    ADD CONSTRAINT api_resthooksubscriber_created_by_id_ff38300d_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_resthooksubscriber api_resthooksubscriber_modified_by_id_0e996ea4_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_resthooksubscriber
    ADD CONSTRAINT api_resthooksubscriber_modified_by_id_0e996ea4_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_resthooksubscriber api_resthooksubscriber_resthook_id_59cd8bc3_fk_api_resthook_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_resthooksubscriber
    ADD CONSTRAINT api_resthooksubscriber_resthook_id_59cd8bc3_fk_api_resthook_id FOREIGN KEY (resthook_id) REFERENCES api_resthook(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_webhookevent api_webhookevent_channel_id_a6c81b11_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookevent
    ADD CONSTRAINT api_webhookevent_channel_id_a6c81b11_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_webhookevent api_webhookevent_created_by_id_2b93b775_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookevent
    ADD CONSTRAINT api_webhookevent_created_by_id_2b93b775_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_webhookevent api_webhookevent_modified_by_id_5f5f505b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookevent
    ADD CONSTRAINT api_webhookevent_modified_by_id_5f5f505b_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_webhookevent api_webhookevent_org_id_2c305947_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookevent
    ADD CONSTRAINT api_webhookevent_org_id_2c305947_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_webhookevent api_webhookevent_resthook_id_d2f95048_fk_api_resthook_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookevent
    ADD CONSTRAINT api_webhookevent_resthook_id_d2f95048_fk_api_resthook_id FOREIGN KEY (resthook_id) REFERENCES api_resthook(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_webhookevent api_webhookevent_run_id_1fcb4900_fk_flows_flowrun_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookevent
    ADD CONSTRAINT api_webhookevent_run_id_1fcb4900_fk_flows_flowrun_id FOREIGN KEY (run_id) REFERENCES flows_flowrun(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_webhookresult api_webhookresult_created_by_id_5f2b29f4_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookresult
    ADD CONSTRAINT api_webhookresult_created_by_id_5f2b29f4_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_webhookresult api_webhookresult_event_id_31528f05_fk_api_webhookevent_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookresult
    ADD CONSTRAINT api_webhookresult_event_id_31528f05_fk_api_webhookevent_id FOREIGN KEY (event_id) REFERENCES api_webhookevent(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_webhookresult api_webhookresult_modified_by_id_b2c2079e_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY api_webhookresult
    ADD CONSTRAINT api_webhookresult_modified_by_id_b2c2079e_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permiss_permission_id_84c5c92e_fk_auth_permission_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permiss_permission_id_84c5c92e_fk_auth_permission_id FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_permission auth_permiss_content_type_id_2f476e4b_fk_django_content_type_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permiss_content_type_id_2f476e4b_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_group_id_97559544_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_group_id_97559544_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_user_id_6a12ed8b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_6a12ed8b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_per_permission_id_1fbb5f2c_fk_auth_permission_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_per_permission_id_1fbb5f2c_fk_auth_permission_id FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: authtoken_token authtoken_token_user_id_35299eff_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY authtoken_token
    ADD CONSTRAINT authtoken_token_user_id_35299eff_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: campaigns_campaignevent campaigns_c_relative_to_id_f8130023_fk_contacts_contactfield_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaignevent
    ADD CONSTRAINT campaigns_c_relative_to_id_f8130023_fk_contacts_contactfield_id FOREIGN KEY (relative_to_id) REFERENCES contacts_contactfield(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: campaigns_campaignevent campaigns_campaig_campaign_id_7752d8e7_fk_campaigns_campaign_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaignevent
    ADD CONSTRAINT campaigns_campaig_campaign_id_7752d8e7_fk_campaigns_campaign_id FOREIGN KEY (campaign_id) REFERENCES campaigns_campaign(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: campaigns_campaign campaigns_campaig_group_id_c1118360_fk_contacts_contactgroup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaign
    ADD CONSTRAINT campaigns_campaig_group_id_c1118360_fk_contacts_contactgroup_id FOREIGN KEY (group_id) REFERENCES contacts_contactgroup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: campaigns_campaign campaigns_campaign_created_by_id_11fada74_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaign
    ADD CONSTRAINT campaigns_campaign_created_by_id_11fada74_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: campaigns_campaign campaigns_campaign_modified_by_id_d578b992_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaign
    ADD CONSTRAINT campaigns_campaign_modified_by_id_d578b992_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: campaigns_campaign campaigns_campaign_org_id_ac7ac4ee_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaign
    ADD CONSTRAINT campaigns_campaign_org_id_ac7ac4ee_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: campaigns_campaignevent campaigns_campaignevent_created_by_id_7755844d_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaignevent
    ADD CONSTRAINT campaigns_campaignevent_created_by_id_7755844d_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: campaigns_campaignevent campaigns_campaignevent_flow_id_7a962066_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaignevent
    ADD CONSTRAINT campaigns_campaignevent_flow_id_7a962066_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: campaigns_campaignevent campaigns_campaignevent_modified_by_id_9645785d_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_campaignevent
    ADD CONSTRAINT campaigns_campaignevent_modified_by_id_9645785d_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: campaigns_eventfire campaigns_event_event_id_f5396422_fk_campaigns_campaignevent_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_eventfire
    ADD CONSTRAINT campaigns_event_event_id_f5396422_fk_campaigns_campaignevent_id FOREIGN KEY (event_id) REFERENCES campaigns_campaignevent(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: campaigns_eventfire campaigns_eventfire_contact_id_7d58f0a5_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY campaigns_eventfire
    ADD CONSTRAINT campaigns_eventfire_contact_id_7d58f0a5_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_alert channels_alert_channel_id_1344ae59_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_alert
    ADD CONSTRAINT channels_alert_channel_id_1344ae59_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_alert channels_alert_created_by_id_1b7c1310_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_alert
    ADD CONSTRAINT channels_alert_created_by_id_1b7c1310_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_alert channels_alert_modified_by_id_e2555348_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_alert
    ADD CONSTRAINT channels_alert_modified_by_id_e2555348_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_alert channels_alert_sync_event_id_c866791c_fk_channels_syncevent_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_alert
    ADD CONSTRAINT channels_alert_sync_event_id_c866791c_fk_channels_syncevent_id FOREIGN KEY (sync_event_id) REFERENCES channels_syncevent(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channelevent channels_chan_contact_urn_id_0d28570b_fk_contacts_contacturn_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelevent
    ADD CONSTRAINT channels_chan_contact_urn_id_0d28570b_fk_contacts_contacturn_id FOREIGN KEY (contact_urn_id) REFERENCES contacts_contacturn(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channelsession channels_chan_contact_urn_id_b8ed9558_fk_contacts_contacturn_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelsession
    ADD CONSTRAINT channels_chan_contact_urn_id_b8ed9558_fk_contacts_contacturn_id FOREIGN KEY (contact_urn_id) REFERENCES contacts_contacturn(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channellog channels_chan_session_id_c80a0f04_fk_channels_channelsession_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channellog
    ADD CONSTRAINT channels_chan_session_id_c80a0f04_fk_channels_channelsession_id FOREIGN KEY (session_id) REFERENCES channels_channelsession(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channel channels_channel_created_by_id_8141adf4_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channel
    ADD CONSTRAINT channels_channel_created_by_id_8141adf4_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channel channels_channel_modified_by_id_af6bcc5e_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channel
    ADD CONSTRAINT channels_channel_modified_by_id_af6bcc5e_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channel channels_channel_org_id_fd34a95a_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channel
    ADD CONSTRAINT channels_channel_org_id_fd34a95a_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channel channels_channel_parent_id_6e9cc8f5_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channel
    ADD CONSTRAINT channels_channel_parent_id_6e9cc8f5_fk_channels_channel_id FOREIGN KEY (parent_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channelcount channels_channelcoun_channel_id_b996d6ab_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelcount
    ADD CONSTRAINT channels_channelcoun_channel_id_b996d6ab_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channelevent channels_channeleven_channel_id_ba42cee7_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelevent
    ADD CONSTRAINT channels_channeleven_channel_id_ba42cee7_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channelevent channels_channeleven_contact_id_054a8a49_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelevent
    ADD CONSTRAINT channels_channeleven_contact_id_054a8a49_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channelevent channels_channelevent_org_id_4d7fff63_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelevent
    ADD CONSTRAINT channels_channelevent_org_id_4d7fff63_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channellog channels_channellog_channel_id_567d1602_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channellog
    ADD CONSTRAINT channels_channellog_channel_id_567d1602_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channellog channels_channellog_msg_id_e40e6612_fk_msgs_msg_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channellog
    ADD CONSTRAINT channels_channellog_msg_id_e40e6612_fk_msgs_msg_id FOREIGN KEY (msg_id) REFERENCES msgs_msg(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channelsession channels_channelsess_channel_id_dbea2097_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelsession
    ADD CONSTRAINT channels_channelsess_channel_id_dbea2097_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channelsession channels_channelsess_contact_id_4fcfc63e_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelsession
    ADD CONSTRAINT channels_channelsess_contact_id_4fcfc63e_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channelsession channels_channelsession_created_by_id_e14d0ce1_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelsession
    ADD CONSTRAINT channels_channelsession_created_by_id_e14d0ce1_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channelsession channels_channelsession_modified_by_id_3fabc050_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelsession
    ADD CONSTRAINT channels_channelsession_modified_by_id_3fabc050_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_channelsession channels_channelsession_org_id_1e76f9d3_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_channelsession
    ADD CONSTRAINT channels_channelsession_org_id_1e76f9d3_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_syncevent channels_syncevent_channel_id_4b72a0f3_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_syncevent
    ADD CONSTRAINT channels_syncevent_channel_id_4b72a0f3_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_syncevent channels_syncevent_created_by_id_1f26df72_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_syncevent
    ADD CONSTRAINT channels_syncevent_created_by_id_1f26df72_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: channels_syncevent channels_syncevent_modified_by_id_3d34e239_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY channels_syncevent
    ADD CONSTRAINT channels_syncevent_modified_by_id_3d34e239_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactgroup_query_fields contacts_c_contactfield_id_4e8430b1_fk_contacts_contactfield_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup_query_fields
    ADD CONSTRAINT contacts_c_contactfield_id_4e8430b1_fk_contacts_contactfield_id FOREIGN KEY (contactfield_id) REFERENCES contacts_contactfield(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactgroup_contacts contacts_c_contactgroup_id_4366e864_fk_contacts_contactgroup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup_contacts
    ADD CONSTRAINT contacts_c_contactgroup_id_4366e864_fk_contacts_contactgroup_id FOREIGN KEY (contactgroup_id) REFERENCES contacts_contactgroup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactgroup_query_fields contacts_c_contactgroup_id_94f3146d_fk_contacts_contactgroup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup_query_fields
    ADD CONSTRAINT contacts_c_contactgroup_id_94f3146d_fk_contacts_contactgroup_id FOREIGN KEY (contactgroup_id) REFERENCES contacts_contactgroup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactgroup contacts_c_import_task_id_5b2cae3f_fk_csv_imports_importtask_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup
    ADD CONSTRAINT contacts_c_import_task_id_5b2cae3f_fk_csv_imports_importtask_id FOREIGN KEY (import_task_id) REFERENCES csv_imports_importtask(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contact contacts_contact_created_by_id_57537352_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contact
    ADD CONSTRAINT contacts_contact_created_by_id_57537352_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contact contacts_contact_modified_by_id_db5cbe12_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contact
    ADD CONSTRAINT contacts_contact_modified_by_id_db5cbe12_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contact contacts_contact_org_id_01d86aa4_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contact
    ADD CONSTRAINT contacts_contact_org_id_01d86aa4_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactfield contacts_contactfield_created_by_id_7bce7fd0_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactfield
    ADD CONSTRAINT contacts_contactfield_created_by_id_7bce7fd0_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactfield contacts_contactfield_modified_by_id_99cfac9b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactfield
    ADD CONSTRAINT contacts_contactfield_modified_by_id_99cfac9b_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactfield contacts_contactfield_org_id_d83cc86a_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactfield
    ADD CONSTRAINT contacts_contactfield_org_id_d83cc86a_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactgroupcount contacts_contactg_group_id_efcdb311_fk_contacts_contactgroup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroupcount
    ADD CONSTRAINT contacts_contactg_group_id_efcdb311_fk_contacts_contactgroup_id FOREIGN KEY (group_id) REFERENCES contacts_contactgroup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactgroup_contacts contacts_contactgrou_contact_id_572f6e61_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup_contacts
    ADD CONSTRAINT contacts_contactgrou_contact_id_572f6e61_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactgroup contacts_contactgroup_created_by_id_6bbeef89_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup
    ADD CONSTRAINT contacts_contactgroup_created_by_id_6bbeef89_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactgroup contacts_contactgroup_modified_by_id_a765a76e_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup
    ADD CONSTRAINT contacts_contactgroup_modified_by_id_a765a76e_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contactgroup contacts_contactgroup_org_id_be850815_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contactgroup
    ADD CONSTRAINT contacts_contactgroup_org_id_be850815_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contacturn contacts_contacturn_channel_id_c3a417df_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contacturn
    ADD CONSTRAINT contacts_contacturn_channel_id_c3a417df_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contacturn contacts_contacturn_contact_id_ae38055c_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contacturn
    ADD CONSTRAINT contacts_contacturn_contact_id_ae38055c_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_contacturn contacts_contacturn_org_id_3cc60a3a_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_contacturn
    ADD CONSTRAINT contacts_contacturn_org_id_3cc60a3a_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_exportcontactstask contacts_exportco_group_id_f623b2c1_fk_contacts_contactgroup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_exportcontactstask
    ADD CONSTRAINT contacts_exportco_group_id_f623b2c1_fk_contacts_contactgroup_id FOREIGN KEY (group_id) REFERENCES contacts_contactgroup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_exportcontactstask contacts_exportcontacts_modified_by_id_212a480d_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_exportcontactstask
    ADD CONSTRAINT contacts_exportcontacts_modified_by_id_212a480d_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_exportcontactstask contacts_exportcontactst_created_by_id_c2721c08_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_exportcontactstask
    ADD CONSTRAINT contacts_exportcontactst_created_by_id_c2721c08_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contacts_exportcontactstask contacts_exportcontactstask_org_id_07dc65f7_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts_exportcontactstask
    ADD CONSTRAINT contacts_exportcontactstask_org_id_07dc65f7_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: csv_imports_importtask csv_imports_importtask_created_by_id_9657a45f_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY csv_imports_importtask
    ADD CONSTRAINT csv_imports_importtask_created_by_id_9657a45f_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: csv_imports_importtask csv_imports_importtask_modified_by_id_282ce6c3_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY csv_imports_importtask
    ADD CONSTRAINT csv_imports_importtask_modified_by_id_282ce6c3_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_actionlog flows_actionlog_run_id_f78d1481_fk_flows_flowrun_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_actionlog
    ADD CONSTRAINT flows_actionlog_run_id_f78d1481_fk_flows_flowrun_id FOREIGN KEY (run_id) REFERENCES flows_flowrun(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_actionset flows_actionset_flow_id_e39e2817_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_actionset
    ADD CONSTRAINT flows_actionset_flow_id_e39e2817_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_exportflowresultstask flows_exportflowresults_modified_by_id_f4871075_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_exportflowresultstask
    ADD CONSTRAINT flows_exportflowresults_modified_by_id_f4871075_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_exportflowresultstask flows_exportflowresultst_created_by_id_43d8e1bd_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_exportflowresultstask
    ADD CONSTRAINT flows_exportflowresultst_created_by_id_43d8e1bd_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_exportflowresultstask_flows flows_exportflowresultstask_f_flow_id_b4c9e790_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_exportflowresultstask_flows
    ADD CONSTRAINT flows_exportflowresultstask_f_flow_id_b4c9e790_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_exportflowresultstask flows_exportflowresultstask_org_id_3a816787_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_exportflowresultstask
    ADD CONSTRAINT flows_exportflowresultstask_org_id_3a816787_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstart_groups flows_flow_contactgroup_id_e2252838_fk_contacts_contactgroup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart_groups
    ADD CONSTRAINT flows_flow_contactgroup_id_e2252838_fk_contacts_contactgroup_id FOREIGN KEY (contactgroup_id) REFERENCES contacts_contactgroup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flow flows_flow_created_by_id_2e1adcb6_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow
    ADD CONSTRAINT flows_flow_created_by_id_2e1adcb6_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flow_labels flows_flow_labels_flow_id_b5b2fc3c_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow_labels
    ADD CONSTRAINT flows_flow_labels_flow_id_b5b2fc3c_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flow_labels flows_flow_labels_flowlabel_id_ce11c90a_fk_flows_flowlabel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow_labels
    ADD CONSTRAINT flows_flow_labels_flowlabel_id_ce11c90a_fk_flows_flowlabel_id FOREIGN KEY (flowlabel_id) REFERENCES flows_flowlabel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flow flows_flow_modified_by_id_493fb4b1_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow
    ADD CONSTRAINT flows_flow_modified_by_id_493fb4b1_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flow flows_flow_org_id_51b9c589_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow
    ADD CONSTRAINT flows_flow_org_id_51b9c589_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flow flows_flow_saved_by_id_edb563b6_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flow
    ADD CONSTRAINT flows_flow_saved_by_id_edb563b6_fk_auth_user_id FOREIGN KEY (saved_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowlabel flows_flowlabel_org_id_4ed2f553_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowlabel
    ADD CONSTRAINT flows_flowlabel_org_id_4ed2f553_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowlabel flows_flowlabel_parent_id_73c0a2dd_fk_flows_flowlabel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowlabel
    ADD CONSTRAINT flows_flowlabel_parent_id_73c0a2dd_fk_flows_flowlabel_id FOREIGN KEY (parent_id) REFERENCES flows_flowlabel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flownodecount flows_flownodecount_flow_id_ba7a0620_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flownodecount
    ADD CONSTRAINT flows_flownodecount_flow_id_ba7a0620_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowpathcount flows_flowpathcount_flow_id_09a7db20_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowpathcount
    ADD CONSTRAINT flows_flowpathcount_flow_id_09a7db20_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowpathrecentstep flows_flowpathrecentstep_step_id_f8a7350b_fk_flows_flowstep_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowpathrecentstep
    ADD CONSTRAINT flows_flowpathrecentstep_step_id_f8a7350b_fk_flows_flowstep_id FOREIGN KEY (step_id) REFERENCES flows_flowstep(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowrevision flows_flowrevision_created_by_id_fb31d40f_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrevision
    ADD CONSTRAINT flows_flowrevision_created_by_id_fb31d40f_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowrevision flows_flowrevision_flow_id_4ae332c8_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrevision
    ADD CONSTRAINT flows_flowrevision_flow_id_4ae332c8_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowrevision flows_flowrevision_modified_by_id_b5464873_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrevision
    ADD CONSTRAINT flows_flowrevision_modified_by_id_b5464873_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowrun flows_flowrun_contact_id_985792a9_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrun
    ADD CONSTRAINT flows_flowrun_contact_id_985792a9_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowrun flows_flowrun_flow_id_9cbb3a32_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrun
    ADD CONSTRAINT flows_flowrun_flow_id_9cbb3a32_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowrun flows_flowrun_org_id_07d5f694_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrun
    ADD CONSTRAINT flows_flowrun_org_id_07d5f694_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowrun flows_flowrun_parent_id_f4daf2da_fk_flows_flowrun_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrun
    ADD CONSTRAINT flows_flowrun_parent_id_f4daf2da_fk_flows_flowrun_id FOREIGN KEY (parent_id) REFERENCES flows_flowrun(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowrun flows_flowrun_session_id_ef240528_fk_channels_channelsession_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrun
    ADD CONSTRAINT flows_flowrun_session_id_ef240528_fk_channels_channelsession_id FOREIGN KEY (session_id) REFERENCES channels_channelsession(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowrun flows_flowrun_start_id_6f5f00b9_fk_flows_flowstart_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrun
    ADD CONSTRAINT flows_flowrun_start_id_6f5f00b9_fk_flows_flowstart_id FOREIGN KEY (start_id) REFERENCES flows_flowstart(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowrun flows_flowrun_submitted_by_id_573c1038_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowrun
    ADD CONSTRAINT flows_flowrun_submitted_by_id_573c1038_fk_auth_user_id FOREIGN KEY (submitted_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowruncount flows_flowruncount_flow_id_6a87383f_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowruncount
    ADD CONSTRAINT flows_flowruncount_flow_id_6a87383f_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstart_contacts flows_flowstart_con_flowstart_id_d8b4cf8f_fk_flows_flowstart_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart_contacts
    ADD CONSTRAINT flows_flowstart_con_flowstart_id_d8b4cf8f_fk_flows_flowstart_id FOREIGN KEY (flowstart_id) REFERENCES flows_flowstart(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstart_contacts flows_flowstart_cont_contact_id_82879510_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart_contacts
    ADD CONSTRAINT flows_flowstart_cont_contact_id_82879510_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstart flows_flowstart_created_by_id_4eb88868_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart
    ADD CONSTRAINT flows_flowstart_created_by_id_4eb88868_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstart flows_flowstart_flow_id_c74e7d30_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart
    ADD CONSTRAINT flows_flowstart_flow_id_c74e7d30_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstart_groups flows_flowstart_gro_flowstart_id_b44aad1f_fk_flows_flowstart_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart_groups
    ADD CONSTRAINT flows_flowstart_gro_flowstart_id_b44aad1f_fk_flows_flowstart_id FOREIGN KEY (flowstart_id) REFERENCES flows_flowstart(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstart flows_flowstart_modified_by_id_c9a338d3_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstart
    ADD CONSTRAINT flows_flowstart_modified_by_id_c9a338d3_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstep_broadcasts flows_flowstep_broad_broadcast_id_9166e6a2_fk_msgs_broadcast_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep_broadcasts
    ADD CONSTRAINT flows_flowstep_broad_broadcast_id_9166e6a2_fk_msgs_broadcast_id FOREIGN KEY (broadcast_id) REFERENCES msgs_broadcast(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstep_broadcasts flows_flowstep_broadc_flowstep_id_36999b7e_fk_flows_flowstep_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep_broadcasts
    ADD CONSTRAINT flows_flowstep_broadc_flowstep_id_36999b7e_fk_flows_flowstep_id FOREIGN KEY (flowstep_id) REFERENCES flows_flowstep(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstep flows_flowstep_contact_id_8becea23_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep
    ADD CONSTRAINT flows_flowstep_contact_id_8becea23_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstep_messages flows_flowstep_messag_flowstep_id_a5e15cad_fk_flows_flowstep_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep_messages
    ADD CONSTRAINT flows_flowstep_messag_flowstep_id_a5e15cad_fk_flows_flowstep_id FOREIGN KEY (flowstep_id) REFERENCES flows_flowstep(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstep_messages flows_flowstep_messages_msg_id_66de5012_fk_msgs_msg_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep_messages
    ADD CONSTRAINT flows_flowstep_messages_msg_id_66de5012_fk_msgs_msg_id FOREIGN KEY (msg_id) REFERENCES msgs_msg(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_flowstep flows_flowstep_run_id_2735b959_fk_flows_flowrun_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_flowstep
    ADD CONSTRAINT flows_flowstep_run_id_2735b959_fk_flows_flowrun_id FOREIGN KEY (run_id) REFERENCES flows_flowrun(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flows_ruleset flows_ruleset_flow_id_adb18930_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY flows_ruleset
    ADD CONSTRAINT flows_ruleset_flow_id_adb18930_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: guardian_groupobjectpermission guardian_gro_content_type_id_7ade36b8_fk_django_content_type_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_groupobjectpermission
    ADD CONSTRAINT guardian_gro_content_type_id_7ade36b8_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: guardian_groupobjectpermission guardian_groupobje_permission_id_36572738_fk_auth_permission_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_groupobjectpermission
    ADD CONSTRAINT guardian_groupobje_permission_id_36572738_fk_auth_permission_id FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: guardian_groupobjectpermission guardian_groupobjectpermissi_group_id_4bbbfb62_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_groupobjectpermission
    ADD CONSTRAINT guardian_groupobjectpermissi_group_id_4bbbfb62_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: guardian_userobjectpermission guardian_use_content_type_id_2e892405_fk_django_content_type_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_userobjectpermission
    ADD CONSTRAINT guardian_use_content_type_id_2e892405_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: guardian_userobjectpermission guardian_userobjec_permission_id_71807bfc_fk_auth_permission_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_userobjectpermission
    ADD CONSTRAINT guardian_userobjec_permission_id_71807bfc_fk_auth_permission_id FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: guardian_userobjectpermission guardian_userobjectpermission_user_id_d5c1e964_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guardian_userobjectpermission
    ADD CONSTRAINT guardian_userobjectpermission_user_id_d5c1e964_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: locations_adminboundary locations_admi_parent_id_03a6640e_fk_locations_adminboundary_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations_adminboundary
    ADD CONSTRAINT locations_admi_parent_id_03a6640e_fk_locations_adminboundary_id FOREIGN KEY (parent_id) REFERENCES locations_adminboundary(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: locations_boundaryalias locations_bo_boundary_id_7ba2d352_fk_locations_adminboundary_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations_boundaryalias
    ADD CONSTRAINT locations_bo_boundary_id_7ba2d352_fk_locations_adminboundary_id FOREIGN KEY (boundary_id) REFERENCES locations_adminboundary(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: locations_boundaryalias locations_boundaryalias_created_by_id_46911c69_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations_boundaryalias
    ADD CONSTRAINT locations_boundaryalias_created_by_id_46911c69_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: locations_boundaryalias locations_boundaryalias_modified_by_id_fabf1a13_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations_boundaryalias
    ADD CONSTRAINT locations_boundaryalias_modified_by_id_fabf1a13_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: locations_boundaryalias locations_boundaryalias_org_id_930a8491_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations_boundaryalias
    ADD CONSTRAINT locations_boundaryalias_org_id_930a8491_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_exportmessagestask_groups ms_exportmessagestask_id_3071019e_fk_msgs_exportmessagestask_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask_groups
    ADD CONSTRAINT ms_exportmessagestask_id_3071019e_fk_msgs_exportmessagestask_id FOREIGN KEY (exportmessagestask_id) REFERENCES msgs_exportmessagestask(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast_groups msgs_broad_contactgroup_id_c8187bee_fk_contacts_contactgroup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_groups
    ADD CONSTRAINT msgs_broad_contactgroup_id_c8187bee_fk_contacts_contactgroup_id FOREIGN KEY (contactgroup_id) REFERENCES contacts_contactgroup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast msgs_broadcast_channel_id_896f7d11_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast
    ADD CONSTRAINT msgs_broadcast_channel_id_896f7d11_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast_contacts msgs_broadcast_conta_broadcast_id_c5dc5132_fk_msgs_broadcast_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_contacts
    ADD CONSTRAINT msgs_broadcast_conta_broadcast_id_c5dc5132_fk_msgs_broadcast_id FOREIGN KEY (broadcast_id) REFERENCES msgs_broadcast(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast_contacts msgs_broadcast_conta_contact_id_9ffd3873_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_contacts
    ADD CONSTRAINT msgs_broadcast_conta_contact_id_9ffd3873_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast_urns msgs_broadcast_contacturn_id_9fe60d63_fk_contacts_contacturn_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_urns
    ADD CONSTRAINT msgs_broadcast_contacturn_id_9fe60d63_fk_contacts_contacturn_id FOREIGN KEY (contacturn_id) REFERENCES contacts_contacturn(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast msgs_broadcast_created_by_id_bc4d5bb1_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast
    ADD CONSTRAINT msgs_broadcast_created_by_id_bc4d5bb1_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast_groups msgs_broadcast_group_broadcast_id_1b1d150a_fk_msgs_broadcast_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_groups
    ADD CONSTRAINT msgs_broadcast_group_broadcast_id_1b1d150a_fk_msgs_broadcast_id FOREIGN KEY (broadcast_id) REFERENCES msgs_broadcast(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast msgs_broadcast_modified_by_id_b51c67df_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast
    ADD CONSTRAINT msgs_broadcast_modified_by_id_b51c67df_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast msgs_broadcast_org_id_78c94f15_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast
    ADD CONSTRAINT msgs_broadcast_org_id_78c94f15_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast msgs_broadcast_parent_id_a2f08782_fk_msgs_broadcast_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast
    ADD CONSTRAINT msgs_broadcast_parent_id_a2f08782_fk_msgs_broadcast_id FOREIGN KEY (parent_id) REFERENCES msgs_broadcast(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast_recipients msgs_broadcast_recip_broadcast_id_4fa1f262_fk_msgs_broadcast_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_recipients
    ADD CONSTRAINT msgs_broadcast_recip_broadcast_id_4fa1f262_fk_msgs_broadcast_id FOREIGN KEY (broadcast_id) REFERENCES msgs_broadcast(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast_recipients msgs_broadcast_recip_contact_id_c2534d9d_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_recipients
    ADD CONSTRAINT msgs_broadcast_recip_contact_id_c2534d9d_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast msgs_broadcast_schedule_id_3bb038fe_fk_schedules_schedule_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast
    ADD CONSTRAINT msgs_broadcast_schedule_id_3bb038fe_fk_schedules_schedule_id FOREIGN KEY (schedule_id) REFERENCES schedules_schedule(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_broadcast_urns msgs_broadcast_urns_broadcast_id_aaf9d7b9_fk_msgs_broadcast_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_broadcast_urns
    ADD CONSTRAINT msgs_broadcast_urns_broadcast_id_aaf9d7b9_fk_msgs_broadcast_id FOREIGN KEY (broadcast_id) REFERENCES msgs_broadcast(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_exportmessagestask_groups msgs_expor_contactgroup_id_3b816325_fk_contacts_contactgroup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask_groups
    ADD CONSTRAINT msgs_expor_contactgroup_id_3b816325_fk_contacts_contactgroup_id FOREIGN KEY (contactgroup_id) REFERENCES contacts_contactgroup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_exportmessagestask msgs_exportmessagestask_created_by_id_f3b48148_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask
    ADD CONSTRAINT msgs_exportmessagestask_created_by_id_f3b48148_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_exportmessagestask msgs_exportmessagestask_label_id_80585f7d_fk_msgs_label_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask
    ADD CONSTRAINT msgs_exportmessagestask_label_id_80585f7d_fk_msgs_label_id FOREIGN KEY (label_id) REFERENCES msgs_label(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_exportmessagestask msgs_exportmessagestask_modified_by_id_d76b3bdf_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask
    ADD CONSTRAINT msgs_exportmessagestask_modified_by_id_d76b3bdf_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_exportmessagestask msgs_exportmessagestask_org_id_8b5afdca_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_exportmessagestask
    ADD CONSTRAINT msgs_exportmessagestask_org_id_8b5afdca_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_label msgs_label_created_by_id_59cd46ee_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_label
    ADD CONSTRAINT msgs_label_created_by_id_59cd46ee_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_label msgs_label_folder_id_fef43746_fk_msgs_label_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_label
    ADD CONSTRAINT msgs_label_folder_id_fef43746_fk_msgs_label_id FOREIGN KEY (folder_id) REFERENCES msgs_label(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_label msgs_label_modified_by_id_8a4d5291_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_label
    ADD CONSTRAINT msgs_label_modified_by_id_8a4d5291_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_label msgs_label_org_id_a63db233_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_label
    ADD CONSTRAINT msgs_label_org_id_a63db233_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_labelcount msgs_labelcount_label_id_3d012b42_fk_msgs_label_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_labelcount
    ADD CONSTRAINT msgs_labelcount_label_id_3d012b42_fk_msgs_label_id FOREIGN KEY (label_id) REFERENCES msgs_label(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_msg msgs_msg_broadcast_id_7514e534_fk_msgs_broadcast_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg
    ADD CONSTRAINT msgs_msg_broadcast_id_7514e534_fk_msgs_broadcast_id FOREIGN KEY (broadcast_id) REFERENCES msgs_broadcast(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_msg msgs_msg_channel_id_0592b6b0_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg
    ADD CONSTRAINT msgs_msg_channel_id_0592b6b0_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_msg msgs_msg_contact_id_5a7d63da_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg
    ADD CONSTRAINT msgs_msg_contact_id_5a7d63da_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_msg msgs_msg_contact_urn_id_fc1da718_fk_contacts_contacturn_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg
    ADD CONSTRAINT msgs_msg_contact_urn_id_fc1da718_fk_contacts_contacturn_id FOREIGN KEY (contact_urn_id) REFERENCES contacts_contacturn(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_msg_labels msgs_msg_labels_label_id_525dfbc1_fk_msgs_label_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg_labels
    ADD CONSTRAINT msgs_msg_labels_label_id_525dfbc1_fk_msgs_label_id FOREIGN KEY (label_id) REFERENCES msgs_label(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_msg_labels msgs_msg_labels_msg_id_a1f8fefa_fk_msgs_msg_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg_labels
    ADD CONSTRAINT msgs_msg_labels_msg_id_a1f8fefa_fk_msgs_msg_id FOREIGN KEY (msg_id) REFERENCES msgs_msg(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_msg msgs_msg_org_id_d3488a20_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg
    ADD CONSTRAINT msgs_msg_org_id_d3488a20_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_msg msgs_msg_response_to_id_9ea625a0_fk_msgs_msg_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg
    ADD CONSTRAINT msgs_msg_response_to_id_9ea625a0_fk_msgs_msg_id FOREIGN KEY (response_to_id) REFERENCES msgs_msg(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_msg msgs_msg_session_id_b96f88e9_fk_channels_channelsession_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg
    ADD CONSTRAINT msgs_msg_session_id_b96f88e9_fk_channels_channelsession_id FOREIGN KEY (session_id) REFERENCES channels_channelsession(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_msg msgs_msg_topup_id_0d2ccb2d_fk_orgs_topup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_msg
    ADD CONSTRAINT msgs_msg_topup_id_0d2ccb2d_fk_orgs_topup_id FOREIGN KEY (topup_id) REFERENCES orgs_topup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: msgs_systemlabelcount msgs_systemlabel_org_id_c6e5a0d7_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY msgs_systemlabelcount
    ADD CONSTRAINT msgs_systemlabel_org_id_c6e5a0d7_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_creditalert orgs_creditalert_created_by_id_902a99c9_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_creditalert
    ADD CONSTRAINT orgs_creditalert_created_by_id_902a99c9_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_creditalert orgs_creditalert_modified_by_id_a7b1b154_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_creditalert
    ADD CONSTRAINT orgs_creditalert_modified_by_id_a7b1b154_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_creditalert orgs_creditalert_org_id_f6caae69_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_creditalert
    ADD CONSTRAINT orgs_creditalert_org_id_f6caae69_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_debit orgs_debit_beneficiary_id_b95fb2b4_fk_orgs_topup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_debit
    ADD CONSTRAINT orgs_debit_beneficiary_id_b95fb2b4_fk_orgs_topup_id FOREIGN KEY (beneficiary_id) REFERENCES orgs_topup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_debit orgs_debit_created_by_id_6e727579_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_debit
    ADD CONSTRAINT orgs_debit_created_by_id_6e727579_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_debit orgs_debit_topup_id_be941fdc_fk_orgs_topup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_debit
    ADD CONSTRAINT orgs_debit_topup_id_be941fdc_fk_orgs_topup_id FOREIGN KEY (topup_id) REFERENCES orgs_topup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_invitation orgs_invitation_created_by_id_147e359a_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_invitation
    ADD CONSTRAINT orgs_invitation_created_by_id_147e359a_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_invitation orgs_invitation_modified_by_id_dd8cae65_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_invitation
    ADD CONSTRAINT orgs_invitation_modified_by_id_dd8cae65_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_invitation orgs_invitation_org_id_d9d2be95_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_invitation
    ADD CONSTRAINT orgs_invitation_org_id_d9d2be95_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_language orgs_language_created_by_id_51a81437_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_language
    ADD CONSTRAINT orgs_language_created_by_id_51a81437_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_language orgs_language_modified_by_id_44fa8893_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_language
    ADD CONSTRAINT orgs_language_modified_by_id_44fa8893_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_language orgs_language_org_id_48328636_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_language
    ADD CONSTRAINT orgs_language_org_id_48328636_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org_administrators orgs_org_administrators_org_id_df1333f0_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_administrators
    ADD CONSTRAINT orgs_org_administrators_org_id_df1333f0_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org_administrators orgs_org_administrators_user_id_74fbbbcb_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_administrators
    ADD CONSTRAINT orgs_org_administrators_user_id_74fbbbcb_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org orgs_org_country_id_c6e479af_fk_locations_adminboundary_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org
    ADD CONSTRAINT orgs_org_country_id_c6e479af_fk_locations_adminboundary_id FOREIGN KEY (country_id) REFERENCES locations_adminboundary(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org orgs_org_created_by_id_f738c068_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org
    ADD CONSTRAINT orgs_org_created_by_id_f738c068_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org_editors orgs_org_editors_org_id_2ac53adb_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_editors
    ADD CONSTRAINT orgs_org_editors_org_id_2ac53adb_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org_editors orgs_org_editors_user_id_21fb7e08_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_editors
    ADD CONSTRAINT orgs_org_editors_user_id_21fb7e08_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org orgs_org_modified_by_id_61e424e7_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org
    ADD CONSTRAINT orgs_org_modified_by_id_61e424e7_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org orgs_org_parent_id_79ba1bbf_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org
    ADD CONSTRAINT orgs_org_parent_id_79ba1bbf_fk_orgs_org_id FOREIGN KEY (parent_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org orgs_org_primary_language_id_595173db_fk_orgs_language_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org
    ADD CONSTRAINT orgs_org_primary_language_id_595173db_fk_orgs_language_id FOREIGN KEY (primary_language_id) REFERENCES orgs_language(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org_surveyors orgs_org_surveyors_org_id_80c50287_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_surveyors
    ADD CONSTRAINT orgs_org_surveyors_org_id_80c50287_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org_surveyors orgs_org_surveyors_user_id_78800efa_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_surveyors
    ADD CONSTRAINT orgs_org_surveyors_user_id_78800efa_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org_viewers orgs_org_viewers_org_id_d7604492_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_viewers
    ADD CONSTRAINT orgs_org_viewers_org_id_d7604492_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_org_viewers orgs_org_viewers_user_id_0650bd4d_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_org_viewers
    ADD CONSTRAINT orgs_org_viewers_user_id_0650bd4d_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_topup orgs_topup_created_by_id_026008e4_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_topup
    ADD CONSTRAINT orgs_topup_created_by_id_026008e4_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_topup orgs_topup_modified_by_id_c6b91b30_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_topup
    ADD CONSTRAINT orgs_topup_modified_by_id_c6b91b30_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_topup orgs_topup_org_id_cde450ed_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_topup
    ADD CONSTRAINT orgs_topup_org_id_cde450ed_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_topupcredits orgs_topupcredits_topup_id_9b2e5f7d_fk_orgs_topup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_topupcredits
    ADD CONSTRAINT orgs_topupcredits_topup_id_9b2e5f7d_fk_orgs_topup_id FOREIGN KEY (topup_id) REFERENCES orgs_topup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: orgs_usersettings orgs_usersettings_user_id_ef7b03af_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs_usersettings
    ADD CONSTRAINT orgs_usersettings_user_id_ef7b03af_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: public_lead public_lead_created_by_id_2da6cfc7_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public_lead
    ADD CONSTRAINT public_lead_created_by_id_2da6cfc7_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: public_lead public_lead_modified_by_id_934f2f0c_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public_lead
    ADD CONSTRAINT public_lead_modified_by_id_934f2f0c_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: public_video public_video_created_by_id_11455096_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public_video
    ADD CONSTRAINT public_video_created_by_id_11455096_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: public_video public_video_modified_by_id_7009d0a7_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public_video
    ADD CONSTRAINT public_video_modified_by_id_7009d0a7_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: reports_report reports_report_created_by_id_e9adac24_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reports_report
    ADD CONSTRAINT reports_report_created_by_id_e9adac24_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: reports_report reports_report_modified_by_id_2c4405a7_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reports_report
    ADD CONSTRAINT reports_report_modified_by_id_2c4405a7_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: reports_report reports_report_org_id_3b235c3d_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reports_report
    ADD CONSTRAINT reports_report_org_id_3b235c3d_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: schedules_schedule schedules_schedule_created_by_id_7a808dd9_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY schedules_schedule
    ADD CONSTRAINT schedules_schedule_created_by_id_7a808dd9_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: schedules_schedule schedules_schedule_modified_by_id_75f3d89a_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY schedules_schedule
    ADD CONSTRAINT schedules_schedule_modified_by_id_75f3d89a_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: triggers_trigger_groups triggers_t_contactgroup_id_648b9858_fk_contacts_contactgroup_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger_groups
    ADD CONSTRAINT triggers_t_contactgroup_id_648b9858_fk_contacts_contactgroup_id FOREIGN KEY (contactgroup_id) REFERENCES contacts_contactgroup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: triggers_trigger triggers_trigger_channel_id_1e8206f8_fk_channels_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger
    ADD CONSTRAINT triggers_trigger_channel_id_1e8206f8_fk_channels_channel_id FOREIGN KEY (channel_id) REFERENCES channels_channel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: triggers_trigger_contacts triggers_trigger_con_contact_id_58bca9a4_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger_contacts
    ADD CONSTRAINT triggers_trigger_con_contact_id_58bca9a4_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: triggers_trigger_contacts triggers_trigger_con_trigger_id_2d7952cd_fk_triggers_trigger_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger_contacts
    ADD CONSTRAINT triggers_trigger_con_trigger_id_2d7952cd_fk_triggers_trigger_id FOREIGN KEY (trigger_id) REFERENCES triggers_trigger(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: triggers_trigger triggers_trigger_created_by_id_265631d7_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger
    ADD CONSTRAINT triggers_trigger_created_by_id_265631d7_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: triggers_trigger triggers_trigger_flow_id_89d39d82_fk_flows_flow_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger
    ADD CONSTRAINT triggers_trigger_flow_id_89d39d82_fk_flows_flow_id FOREIGN KEY (flow_id) REFERENCES flows_flow(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: triggers_trigger_groups triggers_trigger_gro_trigger_id_e3f9e0a9_fk_triggers_trigger_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger_groups
    ADD CONSTRAINT triggers_trigger_gro_trigger_id_e3f9e0a9_fk_triggers_trigger_id FOREIGN KEY (trigger_id) REFERENCES triggers_trigger(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: triggers_trigger triggers_trigger_modified_by_id_6a5f982f_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger
    ADD CONSTRAINT triggers_trigger_modified_by_id_6a5f982f_fk_auth_user_id FOREIGN KEY (modified_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: triggers_trigger triggers_trigger_org_id_4a23f4c2_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger
    ADD CONSTRAINT triggers_trigger_org_id_4a23f4c2_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: triggers_trigger triggers_trigger_schedule_id_22e85233_fk_schedules_schedule_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY triggers_trigger
    ADD CONSTRAINT triggers_trigger_schedule_id_22e85233_fk_schedules_schedule_id FOREIGN KEY (schedule_id) REFERENCES schedules_schedule(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: users_failedlogin users_failedlogin_user_id_d881e023_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users_failedlogin
    ADD CONSTRAINT users_failedlogin_user_id_d881e023_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: users_passwordhistory users_passwordhistory_user_id_1396dbb7_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users_passwordhistory
    ADD CONSTRAINT users_passwordhistory_user_id_1396dbb7_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: users_recoverytoken users_recoverytoken_user_id_0d7bef8c_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users_recoverytoken
    ADD CONSTRAINT users_recoverytoken_user_id_0d7bef8c_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: values_value values_location_value_id_f669603a_fk_locations_adminboundary_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY values_value
    ADD CONSTRAINT values_location_value_id_f669603a_fk_locations_adminboundary_id FOREIGN KEY (location_value_id) REFERENCES locations_adminboundary(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: values_value values_va_contact_field_id_d48e5ab7_fk_contacts_contactfield_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY values_value
    ADD CONSTRAINT values_va_contact_field_id_d48e5ab7_fk_contacts_contactfield_id FOREIGN KEY (contact_field_id) REFERENCES contacts_contactfield(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: values_value values_value_contact_id_c160928a_fk_contacts_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY values_value
    ADD CONSTRAINT values_value_contact_id_c160928a_fk_contacts_contact_id FOREIGN KEY (contact_id) REFERENCES contacts_contact(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: values_value values_value_org_id_ac514e4c_fk_orgs_org_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY values_value
    ADD CONSTRAINT values_value_org_id_ac514e4c_fk_orgs_org_id FOREIGN KEY (org_id) REFERENCES orgs_org(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: values_value values_value_ruleset_id_ad05ba21_fk_flows_ruleset_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY values_value
    ADD CONSTRAINT values_value_ruleset_id_ad05ba21_fk_flows_ruleset_id FOREIGN KEY (ruleset_id) REFERENCES flows_ruleset(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: values_value values_value_run_id_fe1d25b9_fk_flows_flowrun_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY values_value
    ADD CONSTRAINT values_value_run_id_fe1d25b9_fk_flows_flowrun_id FOREIGN KEY (run_id) REFERENCES flows_flowrun(id) DEFERRABLE INITIALLY DEFERRED;


--
-- PostgreSQL database dump complete
--

