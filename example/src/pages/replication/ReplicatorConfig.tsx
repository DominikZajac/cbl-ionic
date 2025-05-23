// Replicator.tsx
import React,
{
  useState,
  useContext
} from 'react';

import DatabaseContext from '../../providers/DatabaseContext';
import ReplicatorContext from '../../providers/ReplicatorContext';

//import container form for the page
import DetailPageContainerRun from '../../components/DetailPageContainerRun/DetailPageContainerRun';

//import forms used for rendering UI on the page
import ReplicatorConfigGeneralForm from '../../components/ReplicatorConfigGeneralForm/ReplicatorConfigGeneralForm';
import AuthenticationTwoFieldForm from '../../components/AuthenticationTwoFieldForm/AuthenticationTwoFieldForm';
import ReplicatorChannelsEditorForm from '../../components/ReplicatorChannelsEditor/ReplicatorChannelsEditor';
import ReplicatorCertificationForm from '../../components/ReplicatorCertificationForm/ReplicatorCertificationForm';

import {
  IonButton,
  IonLabel,
  IonSegment,
  IonSegmentButton
} from '@ionic/react';

import {
  BasicAuthenticator,
  SessionAuthenticator,
  ReplicatorConfiguration,
  URLEndpoint,
  Replicator,
  CollectionConfig
} from 'cbl-ionic';
import { Capacitor } from '@capacitor/core';


const SYNC_GATEWAY_URL = Capacitor.getPlatform() === 'android'
  ? 'ws://10.0.2.2:4984/projects'
  : 'ws://localhost:4984/projects';


const ReplicatorConfigPage: React.FC = () => {
  const { databases } = useContext(DatabaseContext)!;
  const { replicator, setReplicator, setReplicatorConfig } = useContext(ReplicatorContext)!;

  const [databaseName, setDatabaseName] = useState<string>('');

  //used to track the state of the configuration section to show
  const [selectedSegment, setSelectedSegment] = useState<string>('general');

  //used for general configuration fields
  const [connectionString, setConnectionString] = useState<string>('');
  const [headers, setHeaders] = useState<string>('');
  const [selectedReplicatorType, setSelectedReplicatorType] =
    useState<string>('');
  const [heartbeat, setHeartbeat] = useState<number>(60);
  const [maxAttempts, setMaxAttempts] = useState<number>(0);
  const [maxAttemptWaitTime, setMaxAttemptWaitTime] = useState<number>(300);
  const [continuous, setContinuous] = useState<boolean>(true);
  const [autoPurgeEnabled, setAutoPurgeEnabled] = useState<boolean>(true);
  const [acceptParentDomainCookies, setAcceptParentDomainCookies] = useState<boolean>(false);

  //used for authentication type and authentication fields
  const [selectedAuthenticationType, setSelectedAuthenticationType] =
    useState<string>('');
  const [username, setUsername] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [sessionId, setSessionId] = useState<string>('');
  const [cookieName, setCookieName] = useState<string>('');

  //used for certification section
  const [selfSignedCerts, setSelfSignedCerts] = useState<boolean>(true);
  const [pinnedServerCertBase64, setPinnedServerCertBase64] = useState<string>('');

  //used for channels configuration
  const [channels, setChannels] = useState<string>('');

  const [resultsMessage, setResultsMessage] = useState<string[]>([]);

  async function update() {
    if (!databaseName || !(databaseName in databases)) {
      setResultsMessage(['Error: Database is not setup (defined)']);
      return;
    }
    const db = databases[databaseName];
    if (db == null) {
      setResultsMessage(['Error: Database is not setup (defined)']);
      return;
    }

    const defaultCollection = await db.collection('_default');
    const config = new ReplicatorConfiguration(new URLEndpoint(connectionString));

    //general section
    if (headers.length > 0) {
      config.setHeaders(JSON.parse(headers));
    }

    config.setHeartbeat(heartbeat);
    config.setMaxAttemptWaitTime(maxAttemptWaitTime);
    config.setMaxAttempts(maxAttempts);
    switch (selectedReplicatorType) {
      case 'push':
        config.setReplicatorType(ReplicatorConfiguration.ReplicatorType.PUSH);
        break;
      case 'pull':
        config.setReplicatorType(ReplicatorConfiguration.ReplicatorType.PULL);
        break;
      default:
        config.setReplicatorType(ReplicatorConfiguration.ReplicatorType.PUSH_AND_PULL);
        break;
    }
    config.setContinuous(continuous);
    config.setAutoPurgeEnabled(autoPurgeEnabled);
    config.setAcceptParentDomainCookies(acceptParentDomainCookies);

    //auth section
    switch (selectedAuthenticationType) {
      case 'basic':
        config.setAuthenticator(new BasicAuthenticator(username, password));
        break;
      case 'session':
        config.setAuthenticator(new SessionAuthenticator(sessionId, cookieName));
        break;
      default:
        setResultsMessage(['Error: Authentication is not setup (defined)']);
        break;
    }
    //cert section
    config.setAcceptOnlySelfSignedCerts(selfSignedCerts);
    config.setPinnedServerCertificate(pinnedServerCertBase64);
    setReplicatorConfig(config);

    //channel section
    const channelArray = channels.split(',')
      .map(channel => channel.trim())
      .filter(channel => channel.length > 0);
    const collConfig = new CollectionConfig([], []);
    collConfig.setChannels(channelArray);
    config.addCollections([defaultCollection], collConfig);
    try {
      const replicator = await Replicator.create(config);
      setReplicator(replicator);
      setResultsMessage(['Replicator created successfully. To run it, please go to the Replicator Live page.']);
    } catch (error) {
      console.error('Error starting replicator:', error);
      setResultsMessage(prev => [...prev, '❌ Error: ' + error]);
    }
  }

  function reset() {
    setDatabaseName('');

    setConnectionString('');
    setHeaders('');
    setHeartbeat(60);
    setMaxAttempts(0); //resets to default values
    setMaxAttemptWaitTime(300);  //in seconds
    setSelectedReplicatorType('');
    setContinuous(true);
    setAutoPurgeEnabled(true);
    setAcceptParentDomainCookies(false);

    //authentication section
    setSelectedAuthenticationType('');
    setSelectedSegment('general');
    setUsername('');
    setPassword('');
    setSessionId('');
    setCookieName('');

    //cert section
    setSelfSignedCerts(true);
    setPinnedServerCertBase64('');

    //channels section
    setChannels('');

    //cleanup replicator
    if (replicator) {
      replicator.cleanup();
      replicator.stop();
      setReplicator(null);
      setReplicatorConfig(null);
    }

    //results section
    setResultsMessage([]);
  }

  function loadDockerExampleConfig() {
    setConnectionString(SYNC_GATEWAY_URL);
    setSelectedAuthenticationType("basic")
    setUsername("demo@example.com")
    setPassword("P@ssw0rd12")
    setSelectedReplicatorType("PUSH_AND_PULL")
  }

  return (
    <DetailPageContainerRun
      navigationTitle="Replicator Config"
      collapseTitle="Replicator Config"
      onReset={reset}
      onAction={update}
      databaseName={databaseName}
      setDatabaseName={setDatabaseName}
      sectionTitle="Replicator Config"
      titleButtons={null}
      results={resultsMessage}>
      <>
        <IonButton
          expand="full"
          onClick={loadDockerExampleConfig}
          className="m-1">
          Load Docker Example Config
        </IonButton>

        <IonSegment className="mt-4 mb-4" value={selectedSegment}
          onIonChange={e => setSelectedSegment(e.detail.value.toString())}>
          <IonSegmentButton value="general">
            <IonLabel>General</IonLabel>
          </IonSegmentButton>
          <IonSegmentButton value="authentication">
            <IonLabel>Authentication</IonLabel>
          </IonSegmentButton>
          <IonSegmentButton value="certificate">
            <IonLabel>Certification</IonLabel>
          </IonSegmentButton>
          <IonSegmentButton value="channels">
            <IonLabel>Channels</IonLabel>
          </IonSegmentButton>
        </IonSegment>
        {(() => {
          switch (selectedSegment) {
            case 'general':
              return (
                <ReplicatorConfigGeneralForm
                  connectionString={connectionString}
                  setConnectionString={setConnectionString}
                  headers={headers}
                  setHeaders={setHeaders}
                  heartbeat={heartbeat}
                  setHeartbeat={setHeartbeat}
                  maxAttempts={maxAttempts}
                  setMaxAttempts={setMaxAttempts}
                  maxAttemptWaitTime={maxAttemptWaitTime}
                  setMaxAttemptWaitTime={setMaxAttemptWaitTime}
                  selectedReplicatorType={selectedReplicatorType}
                  setSelectedReplicatorType={setSelectedReplicatorType}
                  continuous={continuous}
                  setContinuous={setContinuous}
                  autoPurgeEnabled={autoPurgeEnabled}
                  setAutoPurgeEnabled={setAutoPurgeEnabled}
                  acceptParentDomainCookies={acceptParentDomainCookies}
                  setAcceptParentDomainCookies={setAcceptParentDomainCookies}
                />
              );
            case 'authentication':
              return <AuthenticationTwoFieldForm
                selectedAuthenticationType={selectedAuthenticationType}
                setSelectedAuthenticationType={setSelectedAuthenticationType}
                username={username}
                setUsername={setUsername}
                password={password}
                setPassword={setPassword}
                sessionId={sessionId}
                setSessionId={setSessionId}
                cookieName={cookieName}
                setCookieName={setCookieName}>
              </AuthenticationTwoFieldForm>
            case 'certificate':
              return <ReplicatorCertificationForm
                acceptSelfSignedCertOnly={selfSignedCerts}
                setAcceptSelfSignedCertOnly={setSelfSignedCerts}
                pinnedServerCertBase64={pinnedServerCertBase64}
                setPinnedServerCertBase64={setPinnedServerCertBase64}>
              </ReplicatorCertificationForm>
            case 'channels':
              return <ReplicatorChannelsEditorForm
                channels={channels}
                setChannels={setChannels}>
              </ReplicatorChannelsEditorForm>
            default:
              return null;
          }
        })()}
      </>
    </DetailPageContainerRun>
  );
};

export default ReplicatorConfigPage;
