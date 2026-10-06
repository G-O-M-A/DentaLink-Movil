const express = require('express');
const mysql = require('mysql2');
const cors = require('cors'); 
const { google } = require('googleapis');

const app = express();

app.use(express.json());
app.use(cors());

const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '', 
    database: 'dentalink_db'
});

db.connect(err => {
    if (err) {
        console.error('Error al conectar a la base de datos:', err);
        return;
    }
    console.log('Conectado a la base de datos MySQL de DentaLink');
});


const auth = new google.auth.GoogleAuth({
  keyFile: 'credentials.json', 
  scopes: ['https://www.googleapis.com/auth/calendar'],
});

async function syncToGoogleCalendar(appointmentDetails) {
  const calendar = google.calendar({ version: 'v3', auth });

  const event = {
    summary: 'Ocupado - Espacio Reservado',
    description: `Cita médica reagendada en DentaLink (Motivo: ${appointmentDetails.reason || 'Consulta'})`,
    start: {
      dateTime: appointmentDetails.startDateTime, 
    },
    end: {
      dateTime: appointmentDetails.endDateTime,    
    },
  };

  try {
    const response = await calendar.events.insert({
      calendarId: 'primary',
      resource: event,
    });
    console.log('Evento sincronizado en Google Calendar:', response.data.htmlLink);
  } catch (error) {
    console.error('Error al sincronizar con Google Calendar (Revisa tus credenciales):', error.message);
  }
}


function convertTo24Hour(timeStr) {
  const parts = timeStr.split(' ');
  const time = parts[0];
  const modifier = parts[1];
  let [hours, minutes] = time.split(':');
  
  let h = parseInt(hours, 10);
  if (modifier === 'PM' && h !== 12) h += 12;
  if (modifier === 'AM' && h === 12) h = 0;
  
  return `${String(h).padStart(2, '0')}:${minutes}:00`;
}

function getEndDateTime(dateStr, timeStr) {
  const parts = timeStr.split(' ');
  const time = parts[0];
  const modifier = parts[1];
  let [hours, minutes] = time.split(':');
  
  let h = parseInt(hours, 10);
  if (modifier === 'PM' && h !== 12) h += 12;
  if (modifier === 'AM' && h === 12) h = 0;
  
  let endH = h + 1; 
  return `${dateStr}T${String(endH).padStart(2, '0')}:${minutes}:00-05:00`;
}


app.get('/api/appointments', (req, res) => {
    const query = `
        SELECT a.id, a.patient_name, a.date, a.time, a.reason, a.status, u.name as user_name 
        FROM appointments a 
        JOIN users u ON a.user_id = u.id
    `;
    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

app.patch('/api/appointments/:id/status', (req, res) => {
    const { status } = req.body; 
    const { id } = req.params;
    
    const query = 'UPDATE appointments SET status = ? WHERE id = ?';
    db.query(query, [status, id], (err, result) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'Estado de la cita actualizado correctamente' });
    });
});

app.post('/api/login', (req, res) => {
    const { email, password } = req.body;
    
    const query = 'SELECT * FROM users WHERE email = ? AND password = ?';
    db.query(query, [email, password], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        
        if (results.length > 0) {
            res.json({ success: true, message: 'Login correcto', user: results[0] });
        } else {
            res.status(401).json({ success: false, message: 'Usuario o contraseña incorrectos' });
        }
    });
});

app.patch('/api/appointments/:id/time', async (req, res) => {
  const { id } = req.params;
  const { newTime, newDate } = req.body; 

  const query = 'UPDATE appointments SET time = ?, date = ? WHERE id = ?';
  db.query(query, [newTime, newDate, id], async (err, result) => {
    if (err) {
      console.error('Error al actualizar la cita en la BD:', err);
      return res.status(500).json({ success: false, error: 'Error al actualizar la cita' });
    }

    try {
      const time24 = convertTo24Hour(newTime);
      const startDateTime = `${newDate}T${time24}-05:00`;
      const endDateTime = getEndDateTime(newDate, newTime);

      db.query('SELECT reason FROM appointments WHERE id = ?', [id], async (err2, rows) => {
        const reason = (!err2 && rows.length > 0) ? rows[0].reason : 'Consulta General';
        
        await syncToGoogleCalendar({
          reason: reason,
          startDateTime,
          endDateTime
        });
      });
    } catch (googleErr) {
      console.error('Error al procesar Google Calendar:', googleErr.message);
    }

    res.json({ success: true, message: 'Cita actualizada en base de datos y sincronizada correctamente' });
  });
});

app.listen(3000, () => {
    console.log('Servidor de DentaLink corriendo en http://localhost:3000');
});