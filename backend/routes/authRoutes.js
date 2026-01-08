const express = require('express');
const router = express.Router();
const { register, login, getUsers, deleteUser, updateUser } = require('../controllers/authController');

router.post('/register', register);
router.post('/login', login);
router.get('/users', getUsers);
router.put('/users/:id', updateUser);
router.delete('/users/:id', deleteUser);

module.exports = router;
