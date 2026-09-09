"""Scripted local model protocol for Deputy/shinychat integration checks.

This is test infrastructure, never a fallback model in the Suppose product.
Run separately, then use the factory in dev/run-inquiry-fixture.R.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import time
import sys

START = 'I think fewer meetings would help our team finish work sooner.'
CORRECT = 'By finish sooner I mean elapsed days from starting to completing a work item, next quarter. Keep coordination quality unchanged.'
SLOW = 'Fixture: cancel this slow response.'

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        messages = request['messages']
        user = next(m['content'] for m in reversed(messages) if m['role'] == 'user')
        if isinstance(user, list):
            user = '\n'.join(x.get('text', '') for x in user)
        tools = []
        if messages[-1]['role'] != 'tool' and user in [START, CORRECT, SLOW]:
            args = dict(wording='Fewer recurring meetings may reduce the time our team takes to finish work.',
                        source_quote=user, reason='Scripted reviewable interpretation',
                        target='Elapsed days from starting to completing a work item', scope='Our team',
                        unresolved=['Which recurring meetings would change?'])
            if user == CORRECT:
                args.update(horizon='Next quarter', assumptions=['Keep coordination quality unchanged.'])
            tools = [dict(index=0, id='fixture_interpretation', type='function',
                          function=dict(name='propose_interpretation', arguments=json.dumps(args)))]
        elif user == SLOW:
            time.sleep(12)
        text = ('LOCAL FIXTURE: I proposed a definition of finishing sooner. Which meetings and which period do you have in mind?'
                if user != CORRECT else 'LOCAL FIXTURE: The proposed interpretation now names next quarter and preserving coordination quality. Review it before applying.')
        delta = {'role': 'assistant'}
        if tools:
            delta['tool_calls'] = tools
        else:
            delta['content'] = text
        chunks = []
        for change, finish in [(delta, None), ({}, 'tool_calls' if tools else 'stop')]:
            chunks.append(dict(id='fixture', object='chat.completion.chunk', model='local-inquiry-fixture',
                choices=[dict(index=0, delta=change, finish_reason=finish)]))
        chunks.append(dict(id='fixture', object='chat.completion.chunk', model='local-inquiry-fixture', choices=[],
                           usage=dict(prompt_tokens=100, completion_tokens=50, total_tokens=150)))
        if request.get('stream'):
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream')
            self.end_headers()
            try:
                for chunk in chunks:
                    self.wfile.write(('data: ' + json.dumps(chunk) + '\n\n').encode())
                    self.wfile.flush()
                    if not tools:
                        time.sleep(0.3)
                self.wfile.write(b'data: [DONE]\n\n')
            except BrokenPipeError:
                pass
        else:
            message = dict(role='assistant', content=None if tools else text)
            if tools:
                message['tool_calls'] = [{k:v for k,v in t.items() if k != 'index'} for t in tools]
            response = dict(id='fixture', object='chat.completion', model='local-inquiry-fixture',
                            choices=[dict(index=0, message=message, finish_reason='tool_calls' if tools else 'stop')],
                            usage=dict(prompt_tokens=100, completion_tokens=50, total_tokens=150))
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
    def log_message(self, *args):
        pass

ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1]) if len(sys.argv) > 1 else 3893), Handler).serve_forever()
